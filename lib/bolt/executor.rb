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
        'ssh' => Concurrent::Delay.new { Bolt::Transport::SSH.new(config[:transports][:ssh] || {}) },
        'winrm' => Concurrent::Delay.new { Bolt::Transport::WinRM.new(config[:transports][:winrm] || {}) },
        'pcp' => Concurrent::Delay.new { Bolt::Transport::Orch.new(config[:transports][:pcp] || {}) }
      }

      # If a specific elevated log level has been requested, honor that.
      # Otherwise, escalate the log level to "info" if running in plan mode, so
      # that certain progress messages will be visible.
      default_log_level = plan_logging ? :info : :notice
      @logger.level = @config[:log_level] || default_log_level
      @noop = noop
      @run_as = nil
      @pool = Concurrent::CachedThreadPool.new(max_threads: @config[:concurrency])
      @logger.debug { "Started with #{@config[:concurrency]} max thread(s)" }
      @notifier = Bolt::Notifier.new
    end

    def transport(transport)
      @transports[transport || 'ssh'].value
    end

    def summary(action, object, result)
      fc = result.error_set.length
      npl = result.length == 1 ? '' : 's'
      fpl = fc == 1 ? '' : 's'
      "Ran #{action} '#{object}' on #{result.length} node#{npl} with #{fc} failure#{fpl}"
    end
    private :summary

    def run_command(targets, command, options = {}, &callback)
      @logger.info("Starting command run '#{command}' on #{targets.map(&:uri)}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      result_futures = targets.group_by(&:protocol).flat_map do |protocol, batch|
        transport(protocol).batch_command(batch, command, options, &notify)
      end
      results = ResultSet.new(result_futures.map(&:value))
      @logger.info(summary('command', command, results))
      @notifier.shutdown
      results
    end

    def run_script(targets, script, arguments, options = {}, &callback)
      @logger.info("Starting script run #{script} on #{targets.map(&:uri)}")
      @logger.debug("Arguments: #{arguments}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      result_futures = targets.group_by(&:protocol).flat_map do |protocol, batch|
        transport(protocol).batch_script(batch, script, arguments, options, &notify)
      end
      results = ResultSet.new(result_futures.map(&:value))
      @logger.info(summary('script', script, results))
      @notifier.shutdown
      results
    end

    def run_task(targets, task, input_method, arguments, options = {}, &callback)
      @logger.info("Starting task #{task} on #{targets.map(&:uri)}")
      @logger.debug("Arguments: #{arguments} Input method: #{input_method}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      result_futures = targets.group_by(&:protocol).flat_map do |protocol, batch|
        transport(protocol).batch_task(batch, task, input_method, arguments, options, &notify)
      end
      results = ResultSet.new(result_futures.map(&:value))
      @logger.info(summary('task', task, results))
      @notifier.shutdown
      results
    end

    def file_upload(targets, source, destination, options = {}, &callback)
      @logger.info("Starting file upload from #{source} to #{destination} on #{targets.map(&:uri)}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      result_futures = targets.group_by(&:protocol).flat_map do |protocol, batch|
        transport(protocol).batch_upload(batch, source, destination, options, &notify)
      end
      results = ResultSet.new(result_futures.map(&:value))
      @logger.info(summary('upload', source, results))
      @notifier.shutdown
      results
    end
  end
end
