require 'bolt/logger'
require 'json'
require 'concurrent'
require 'bolt/result'
require 'bolt/config'
require 'bolt/notifier'

module Bolt
  class Executor
    attr_reader :noop

    def initialize(config = Bolt::Config.new, noop = nil, plan_logging = false)
      @config = config
      @logger = Logger.get_logger(progname: 'executor')
      @noop = noop
      @notifier = Bolt::Notifier.new
      @plan_logging = plan_logging
    end

    def from_uris(nodes)
      nodes.map do |node|
        Bolt::Node.from_uri(node, config: @config)
      end
    end

    def on(nodes, callback = nil)
      results = Concurrent::Map.new

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
              @notifier.notify(callback, node, type: :node_start) if callback
              node.connect
              yield node
            rescue StandardError => ex
              Bolt::Result.from_exception(ex)
            ensure
              begin
                node.disconnect
              rescue StandardError => ex
                @logger.info("Failed to close connection to #{node.uri} : #{ex.message}")
              end
            end
          results[node] = result
          if callback
            @notifier.notify(callback, node, type: :node_result, result: result)
          end
          result
        end
      }
      pool.shutdown
      pool.wait_for_termination

      @notifier.shutdown

      results_to_hash(results)
    end

    def summary(action, object, result)
      fc = result.select { |_, r| r.error }.length
      npl = result.length == 1 ? '' : 's'
      fpl = fc == 1 ? '' : 's'
      "Ran #{action} '#{object}' on #{result.length} node#{npl} with #{fc} failure#{fpl}"
    end

    def run_command(nodes, command)
      level = @plan_logging ? Logger::NOTICE : Logger::INFO
      @logger.log(level, "Starting command run '#{command}' on #{nodes.map(&:uri)}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug("Running command '#{command}' on #{node.uri}")
        node_result = node.run_command(command)
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.to_result)}")
        node_result
      end
      @logger.log(level, summary('command', command, r))
      r
    end

    def run_script(nodes, script, arguments)
      level = @plan_logging ? Logger::NOTICE : Logger::INFO
      @logger.log(level, "Starting script run #{script} on #{nodes.map(&:uri)}")
      @logger.debug("Arguments: #{arguments}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug { "Running script '#{script}' on #{node.uri}" }
        node_result = node.run_script(script, arguments)
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.to_result)}")
        node_result
      end
      @logger.log(level, summary('script', script, r))
      r
    end

    def run_task(nodes, task, input_method, arguments)
      level = @plan_logging ? Logger::NOTICE : Logger::INFO
      @logger.log(level, "Starting task #{task} on #{nodes.map(&:uri)}")
      @logger.debug("Arguments: #{arguments} Input method: #{input_method}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug { "Running task run '#{task}' on #{node.uri}" }
        node_result = node.run_task(task, input_method, arguments)
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.to_result)}")
        node_result
      end
      @logger.log(level, summary('task', task, r))
      r
    end

    def file_upload(nodes, source, destination)
      level = @plan_logging ? Logger::NOTICE : Logger::INFO
      @logger.log(level, "Starting file upload from #{source} to #{destination} on #{nodes.map(&:uri)}")
      callback = block_given? ? Proc.new : nil

      r = on(nodes, callback) do |node|
        @logger.debug { "Uploading: '#{source}' to #{node.uri}" }
        node_result = node.upload(source, destination)
        @logger.debug("Result on #{node.uri}: #{JSON.dump(node_result.to_result)}")
        node_result
      end
      @logger.log(level, summary('upload', source, r))
      r
    end

    private

    def results_to_hash(results)
      result_hash = {}
      results.each_pair { |k, v| result_hash[k] = v }
      result_hash
    end
  end
end
