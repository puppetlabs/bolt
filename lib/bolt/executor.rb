require 'json'
require 'concurrent'
require 'logging'
require 'bolt/result'
require 'bolt/config'
require 'bolt/notifier'
require 'bolt/node'
require 'bolt/result_set'

module Bolt
  class Executor
    attr_reader :noop
    attr_accessor :run_as

    def initialize(config = Bolt::Config.new, noop = nil, plan_logging = false)
      @config = config
      @logger = Logging.logger[self]

      # If a specific elevated log level has been requested, honor that.
      # Otherwise, escalate the log level to "info" if running in plan mode, so
      # that certain progress messages will be visible.
      default_log_level = plan_logging ? :info : :notice
      @logger.level = @config[:log_level] || default_log_level
      @noop = noop
      @run_as = nil
      @notifier = Bolt::Notifier.new
    end

    def from_targets(targets)
      targets.map do |target|
        Bolt::Node.from_target(target)
      end
    end
    private :from_targets

    def on(nodes, callback = nil)
      results = Concurrent::Array.new

      poolsize = [nodes.length, @config[:concurrency]].min
      pool = Concurrent::FixedThreadPool.new(poolsize)
      @logger.debug { "Started with #{poolsize} thread(s)" }

      nodes.map(&:class).uniq.each do |klass|
        klass.initialize_transport(@logger)
      end

      nodes.each { |node|
        pool.post do
          result =
            begin
              @notifier.notify(callback, type: :node_start, target: node.target) if callback
              node.connect
              yield node
            rescue StandardError => ex
              Bolt::Result.from_exception(node.target, ex)
            ensure
              begin
                node.disconnect
              rescue StandardError => ex
                @logger.info("Failed to close connection to #{node.uri} : #{ex.message}")
              end
            end
          results.concat([result])
          @notifier.notify(callback, type: :node_result, result: result) if callback
        end
      }
      pool.shutdown
      pool.wait_for_termination

      @notifier.shutdown

      Bolt::ResultSet.new(results)
    end
    private :on

    def summary(action, object, result)
      fc = result.error_set.length
      npl = result.length == 1 ? '' : 's'
      fpl = fc == 1 ? '' : 's'
      "Ran #{action} '#{object}' on #{result.length} node#{npl} with #{fc} failure#{fpl}"
    end
    private :summary

    def get_run_as(node, options)
      if node.run_as.nil? && run_as
        { '_run_as' => run_as }.merge(options)
      else
        options
      end
    end
    private :get_run_as

    def with_exception_handling(node)
      yield
    rescue StandardError => e
      Bolt::Result.from_exception(node.target, e)
    end
    private :with_exception_handling

    def run_command(targets, command, options = {})
      nodes = from_targets(targets)
      @logger.info("Starting command run '#{command}' on #{nodes.map(&:uri)}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug("Running command '#{command}' on #{node.uri}")
        node_result = with_exception_handling(node) do
          node.run_command(command, get_run_as(node, options))
        end
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.value)}")
        node_result
      end
      @logger.info(summary('command', command, r))
      r
    end

    def run_script(targets, script, arguments, options = {})
      nodes = from_targets(targets)
      @logger.info("Starting script run #{script} on #{nodes.map(&:uri)}")
      @logger.debug("Arguments: #{arguments}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug { "Running script '#{script}' on #{node.uri}" }
        node_result = with_exception_handling(node) do
          node.run_script(script, arguments, get_run_as(node, options))
        end
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.value)}")
        node_result
      end
      @logger.info(summary('script', script, r))
      r
    end

    def run_task(targets, task, input_method, arguments, options = {})
      nodes = from_targets(targets)
      @logger.info("Starting task #{task} on #{nodes.map(&:uri)}")
      @logger.debug("Arguments: #{arguments} Input method: #{input_method}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug { "Running task run '#{task}' on #{node.uri}" }
        node_result = with_exception_handling(node) do
          node.run_task(task, input_method, arguments, get_run_as(node, options))
        end
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.value)}")
        node_result
      end
      @logger.info(summary('task', task, r))
      r
    end

    def file_upload(targets, source, destination)
      nodes = from_targets(targets)
      @logger.info("Starting file upload from #{source} to #{destination} on #{nodes.map(&:uri)}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug { "Uploading: '#{source}' to #{destination} on #{node.uri}" }
        node_result = with_exception_handling(node) do
          node.upload(source, destination)
        end
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.value)}")
        node_result
      end
      @logger.info(summary('upload', source, r))
      r
    end
  end
end
