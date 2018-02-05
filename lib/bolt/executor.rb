require 'json'
require 'concurrent'
require 'logging'
require 'bolt/result'
require 'bolt/config'
require 'bolt/notifier'
require 'bolt/result_set'
require 'bolt/transport/ssh'
require 'bolt/transport/winrm'
require 'bolt/transport/orch'

module Bolt
  class Executor
    attr_reader :noop, :transports
    attr_accessor :run_as

    def initialize(config = Bolt::Config.new, noop = nil, plan_logging = false)
      @config = config
      @logger = Logging.logger[self]

      @transports = {
        'ssh' => Bolt::Transport::SSH.new(config[:transports][:ssh] || {}),
        'winrm' => Bolt::Transport::WinRM.new(config[:transports][:winrm] || {}),
        'pcp' => Bolt::Transport::Orch.new(config[:transports][:pcp] || {})
      }

      # If a specific elevated log level has been requested, honor that.
      # Otherwise, escalate the log level to "info" if running in plan mode, so
      # that certain progress messages will be visible.
      default_log_level = plan_logging ? :info : :notice
      @logger.level = @config[:log_level] || default_log_level
      @noop = noop
      @run_as = nil
      @notifier = Bolt::Notifier.new
    end

    def on(targets, callback = nil)
      results = Concurrent::Array.new

      poolsize = [targets.length, @config[:concurrency]].min
      pool = Concurrent::FixedThreadPool.new(poolsize)
      @logger.debug { "Started with #{poolsize} thread(s)" }

      targets.each { |target|
        pool.post do
          result =
            begin
              transport = @transports[target.protocol || 'ssh']
              @notifier.notify(callback, type: :node_start, target: target) if callback
              yield transport, target
            rescue StandardError => ex
              Bolt::Result.from_exception(target, ex)
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

    def get_run_as(target, options)
      if target.options[:run_as].nil? && run_as
        { '_run_as' => run_as }.merge(options)
      else
        options
      end
    end
    private :get_run_as

    def with_exception_handling(target)
      yield
    rescue StandardError => e
      Bolt::Result.from_exception(target, e)
    end
    private :with_exception_handling

    def run_command(targets, command, options = {})
      @logger.info("Starting command run '#{command}' on #{targets.map(&:uri)}")
      callback = block_given? ? Proc.new : nil

      r = on(targets, callback) do |transport, target|
        @logger.debug("Running command '#{command}' on #{target.uri}")
        target_result = with_exception_handling(target) do
          transport.run_command(target, command, get_run_as(target, options))
        end
        @logger.debug("Result on #{target.uri}: #{JSON.dump(target_result.value)}")
        target_result
      end
      @logger.info(summary('command', command, r))
      r
    end

    def run_script(targets, script, arguments, options = {})
      @logger.info("Starting script run #{script} on #{targets.map(&:uri)}")
      @logger.debug("Arguments: #{arguments}")
      callback = block_given? ? Proc.new : nil

      r = on(targets, callback) do |transport, target|
        @logger.debug { "Running script '#{script}' on #{target.uri}" }
        target_result = with_exception_handling(target) do
          transport.run_script(target, script, arguments, get_run_as(target, options))
        end
        @logger.debug("Result on #{target.uri}: #{JSON.dump(target_result.value)}")
        target_result
      end
      @logger.info(summary('script', script, r))
      r
    end

    def run_task(targets, task, input_method, arguments, options = {})
      @logger.info("Starting task #{task} on #{targets.map(&:uri)}")
      @logger.debug("Arguments: #{arguments} Input method: #{input_method}")
      callback = block_given? ? Proc.new : nil

      r = on(targets, callback) do |transport, target|
        @logger.debug { "Running task run '#{task}' on #{target.uri}" }
        target_result = with_exception_handling(target) do
          transport.run_task(target, task, input_method, arguments, get_run_as(target, options))
        end
        @logger.debug("Result on #{target.uri}: #{JSON.dump(target_result.value)}")
        target_result
      end
      @logger.info(summary('task', task, r))
      r
    end

    def file_upload(targets, source, destination, options = {})
      @logger.info("Starting file upload from #{source} to #{destination} on #{targets.map(&:uri)}")
      callback = block_given? ? Proc.new : nil

      r = on(targets, callback) do |transport, target|
        @logger.debug { "Uploading: '#{source}' to #{destination} on #{target.uri}" }
        target_result = with_exception_handling(target) do
          transport.upload(target, source, destination, options)
        end
        @logger.debug("Result on #{target.uri}: #{JSON.dump(target_result.value)}")
        target_result
      end
      @logger.info(summary('upload', source, r))
      r
    end
  end
end
