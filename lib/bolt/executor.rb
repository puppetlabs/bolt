# Used for $ERROR_INFO. This *must* be capitalized!
require 'English'
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

    # Execute the given block on a list of nodes in parallel, one thread per "batch".
    #
    # This is the main driver of execution on a list of targets. It first
    # groups targets by transport, then divides each group into batches as
    # defined by the transport. Each batch, along with the corresponding
    # transport, is yielded to the block in turn and the results all collected
    # into a single ResultSet.
    def batch_execute(targets)
      promises = targets.group_by(&:protocol).flat_map do |protocol, _protocol_targets|
        transport = transport(protocol)
        transport.batches(targets).flat_map do |batch|
          batch_promises = Hash[Array(batch).map { |target| [target, Concurrent::Promise.new(executor: :immediate)] }]
          # Pass this argument through to avoid retaining a reference to a
          # local variable that will change on the next iteration of the loop.
          @pool.post(batch_promises) do |result_promises|
            begin
              results = yield transport, batch
              Array(results).each do |result|
                result_promises[result.target].set(result)
              end
            # NotImplementedError can be thrown if the transport is implemented improperly
            rescue StandardError, NotImplementedError => e
              result_promises.each do |target, promise|
                promise.set(Bolt::Result.from_exception(target, e))
              end
            ensure
              # Make absolutely sure every promise gets a result to avoid a
              # deadlock. Use whatever exception is causing this block to
              # execute, or generate one if we somehow got here without an
              # exception and some promise is still missing a result.
              result_promises.each do |target, promise|
                next if promise.fulfilled?
                error = $ERROR_INFO || Bolt::Error.new("No result was returned for #{target.uri}",
                                                       "puppetlabs.bolt/missing-result-error")
                promise.set(Bolt::Result.from_exception(error))
              end
            end
          end
          batch_promises.values
        end
      end
      ResultSet.new(promises.map(&:value))
    end

    def run_command(targets, command, options = {}, &callback)
      @logger.info("Starting command run '#{command}' on #{targets.map(&:uri)}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_command(batch, command, options, &notify)
      end

      @logger.info(summary('command', command, results))
      @notifier.shutdown
      results
    end

    def run_script(targets, script, arguments, options = {}, &callback)
      @logger.info("Starting script run #{script} on #{targets.map(&:uri)}")
      @logger.debug("Arguments: #{arguments}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_script(batch, script, arguments, options, &notify)
      end

      @logger.info(summary('script', script, results))
      @notifier.shutdown
      results
    end

    def run_task(targets, task, arguments, options = {}, &callback)
      task_name = task.name
      @logger.info("Starting task #{task_name} on #{targets.map(&:uri)}")
      @logger.debug("Arguments: #{arguments} Input method: #{task.input_method}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_task(batch, task, arguments, options, &notify)
      end

      @logger.info(summary('task', task_name, results))
      @notifier.shutdown
      results
    end

    def file_upload(targets, source, destination, options = {}, &callback)
      @logger.info("Starting file upload from #{source} to #{destination} on #{targets.map(&:uri)}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_upload(batch, source, destination, options, &notify)
      end

      @logger.info(summary('upload', source, results))
      @notifier.shutdown
      results
    end
  end
end
