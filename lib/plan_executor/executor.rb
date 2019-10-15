# frozen_string_literal: true

# Used for $ERROR_INFO. This *must* be capitalized!
require 'English'
require 'json'
require 'logging'
require 'set'
require 'bolt/result'
require 'bolt/config'
require 'bolt/result_set'
require 'bolt/puppetdb'
require 'plan_executor/orch_client'

module PlanExecutor
  class Executor
    attr_reader :noop, :logger
    attr_accessor :orch_client

    def initialize(job_id, http_client, noop = nil)
      @logger = Logging.logger[self]
      @plan_logging = false
      @noop = noop
      @logger.debug { "Started" }
      @orch_client = PlanExecutor::OrchClient.new(job_id, http_client, @logger)
    end

    # This handles running the job, catching errors, and turning the result
    # into a result set
    def as_resultset(targets)
      result_array = begin
                       yield
                     rescue StandardError => e
                       @logger.warn(e)
                       # CODEREVIEW how should we fail if there's an error?
                       Array(Bolt::Result.from_exception(targets[0], e))
                     end
      Bolt::ResultSet.new(result_array)
    end

    # BOLT-1098
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

    # BOLT-1098
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

    def run_command(targets, command, options = {})
      description = options.fetch(:description, "command '#{command}'")
      log_action(description, targets) do
        results = as_resultset(targets) do
          @orch_client.run_command(targets, command, options)
        end

        results
      end
    end

    def run_script(targets, script, arguments, options = {})
      description = options.fetch(:description, "script #{script}")
      log_action(description, targets) do
        results = as_resultset(targets) do
          @orch_client.run_script(targets, script, arguments, options)
        end

        results
      end
    end

    def run_task(targets, task, arguments, options = {})
      description = options.fetch(:description, "task #{task.name}")
      log_action(description, targets) do
        arguments['_task'] = task.name

        results = as_resultset(targets) do
          @orch_client.run_task(targets, task, arguments, options)
        end

        results
      end
    end

    def upload_file(targets, source, destination, options = {})
      description = options.fetch(:description, "file upload from #{source} to #{destination}")
      log_action(description, targets) do
        results = as_resultset(targets) do
          @orch_client.file_upload(targets, source, destination, options)
        end

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
          wait_until(wait_time, retry_interval) { @orch_client.connected?(targets) }
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

    def finish_plan(plan_result)
      @orch_client.finish_plan(plan_result)
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
