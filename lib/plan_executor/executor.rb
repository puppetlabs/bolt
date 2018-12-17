# frozen_string_literal: true

# Used for $ERROR_INFO. This *must* be capitalized!
require 'English'
require 'json'
require 'logging'
require 'set'
require 'bolt/result'
require 'bolt/config'
require 'bolt/transport/api'
require 'bolt/notifier'
require 'bolt/result_set'
require 'bolt/puppetdb'

module PlanExecutor
  class Executor
    attr_reader :noop, :transport

    def initialize(noop = nil)
      @logger = Logging.logger[self]
      @plan_logging = false
      @noop = noop
      @logger.debug { "Started" }
      @notifier = Bolt::Notifier.new
      @transport = Bolt::Transport::Api.new
    end

    # This handles running the job, catching errors, and turning the result
    # into a result set
    def execute(targets)
      result_array = begin
                       yield
                     rescue StandardError => e
                       @logger.warn(e)
                       # CODEREVIEW how should we fail if there's an error?
                       Array(Bolt::Result.from_exception(targets[0], e))
                     end
      Bolt::ResultSet.new(result_array)
    end

    # TODO: Remove in favor of service logging
    def log_action(description, targets)
      # When running a plan, info messages like starting a task are promoted to notice.
      log_method = @plan_logging ? :notice : :info
      target_str = if targets.length > 5
                     "#{targets.count} targets"
                   else
                     targets.map(&:uri).join(', ')
                   end

      @logger.send(log_method, "Starting: #{description} on #{target_str}")

      start_time = Time.now
      results = yield
      duration = Time.now - start_time

      failures = results.error_set.length
      plural = failures == 1 ? '' : 's'

      @logger.send(log_method, "Finished: #{description} with #{failures} failure#{plural} in #{duration.round(2)} sec")

      results
    end

    def log_plan(plan_name)
      log_method = @plan_logging ? :notice : :info
      @logger.send(log_method, "Starting: plan #{plan_name}")
      start_time = Time.now

      results = nil
      begin
        results = yield
      ensure
        duration = Time.now - start_time
        @logger.send(log_method, "Finished: plan #{plan_name} in #{duration.round(2)} sec")
      end

      results
    end

    def run_command(targets, command, options = {}, &callback)
      description = options.fetch('_description', "command '#{command}'")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }

        results = execute(targets) do
          @transport.batch_command(targets, command, options, &notify)
        end

        @notifier.shutdown
        results
      end
    end

    def run_script(targets, script, arguments, options = {}, &callback)
      description = options.fetch('_description', "script #{script}")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }

        results = execute(targets) do
          @transport.batch_script(targets, script, arguments, options, &notify)
        end

        @notifier.shutdown
        results
      end
    end

    def run_task(targets, task, arguments, options = {}, &callback)
      description = options.fetch('_description', "task #{task.name}")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }

        arguments['_task'] = task.name

        results = execute(targets) do
          @transport.batch_task(targets, task, arguments, options, &notify)
        end

        @notifier.shutdown
        results
      end
    end

    def upload_file(targets, source, destination, options = {}, &callback)
      description = options.fetch('_description', "file upload from #{source} to #{destination}")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }

        results = execute(targets) do
          @transport.batch_upload(targets, source, destination, options, &notify)
        end

        @notifier.shutdown
        results
      end
    end

    class TimeoutError < RuntimeError; end

    def wait_until_available(targets,
                             description: 'wait until available',
                             wait_time: 120,
                             retry_interval: 1)
      log_action(description, targets) do
        begin
          wait_until(wait_time, retry_interval) { @transport.batch_connected?(targets) }
          targets.map { |target| Bolt::Result.new(target) }
        rescue TimeoutError => e
          targets.map { |target| Bolt::Result.from_exception(target, e) }
        end
      end
    end

    def wait_until(timeout, retry_interval)
      start = wait_now
      until yield
        raise(TimeoutError, 'Timed out waiting for target') if (wait_now - start).to_i >= timeout
        sleep(retry_interval)
      end
    end

    # Plan context doesn't make sense for most transports but it is tightly
    # coupled with the orchestrator transport since the transport behaves
    # differently when a plan is running. In order to limit how much this
    # pollutes the transport API we only handle the orchestrator transport here.
    # Since we callt this function without resolving targets this will result
    # in the orchestrator transport always being initialized during plan runs.
    # For now that's ok.
    #
    # In the future if other transports need this or if we want a plan stack
    # we'll need to refactor.
    def start_plan(plan_context)
      @transport.plan_context = plan_context
      @plan_logging = true
    end

    def finish_plan(plan_result)
      @transport.finish_plan(plan_result)
    end

    def without_default_logging
      old_log = @plan_logging
      @plan_logging = false
      yield
    ensure
      @plan_logging = old_log
    end

    def report_bundled_content(mode, name); end

    def report_function_call(function); end
  end
end
