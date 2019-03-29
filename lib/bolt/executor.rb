# frozen_string_literal: true

# Used for $ERROR_INFO. This *must* be capitalized!
require 'English'
require 'json'
require 'logging'
require 'set'
require 'bolt/analytics'
require 'bolt/result'
require 'bolt/config'
require 'bolt/notifier'
require 'bolt/result_set'
require 'bolt/puppetdb'

module Bolt
  class Executor
    attr_reader :noop, :transports
    attr_accessor :run_as

    # FIXME: There must be a better way
    # https://makandracards.com/makandra/36011-ruby-do-not-mix-optional-and-keyword-arguments
    def initialize(concurrency = 1,
                   analytics = Bolt::Analytics::NoopClient.new,
                   noop = nil,
                   bundled_content: nil,
                   load_config: true)

      # lazy-load expensive gem code
      require 'concurrent'

      @analytics = analytics
      @bundled_content = bundled_content
      @logger = Logging.logger[self]
      @load_config = load_config

      @transports = Bolt::TRANSPORTS.each_with_object({}) do |(key, val), coll|
        coll[key.to_s] = if key == :remote
                           Concurrent::Delay.new do
                             val.new(self)
                           end
                         else
                           Concurrent::Delay.new do
                             val.new
                           end
                         end
      end
      @reported_transports = Set.new

      @noop = noop
      @run_as = nil
      @pool = if concurrency > 0
                Concurrent::ThreadPoolExecutor.new(max_threads: concurrency)
              else
                Concurrent.global_immediate_executor
              end
      @logger.debug { "Started with #{concurrency} max thread(s)" }
      @notifier = Bolt::Notifier.new
    end

    def transport(transport)
      impl = @transports[transport || 'ssh']
      raise(Bolt::UnknownTransportError, transport) unless impl
      # If there was an error creating the transport, ensure it gets thrown
      impl.no_error!
      impl.value
    end

    # Starts executing the given block on a list of nodes in parallel, one thread per "batch".
    #
    # This is the main driver of execution on a list of targets. It first
    # groups targets by transport, then divides each group into batches as
    # defined by the transport. Yields each batch, along with the corresponding
    # transport, to the block in turn and returns an array of result promises.
    def queue_execute(targets)
      targets.group_by(&:transport).flat_map do |protocol, protocol_targets|
        transport = transport(protocol)
        report_transport(transport, protocol_targets.count)
        transport.batches(protocol_targets).flat_map do |batch|
          batch_promises = Array(batch).each_with_object({}) do |target, h|
            h[target] = Concurrent::Promise.new(executor: :immediate)
          end
          # Pass this argument through to avoid retaining a reference to a
          # local variable that will change on the next iteration of the loop.
          @pool.post(batch_promises) do |result_promises|
            begin
              results = yield transport, batch
              Array(results).each do |result|
                result_promises[result.target].set(result)
              end
            # NotImplementedError can be thrown if the transport is not implemented improperly
            rescue StandardError, NotImplementedError => e
              result_promises.each do |target, promise|
                # If an exception happens while running, the result won't be logged
                # by the CLI. Log a warning, as this is probably a problem with the transport.
                # If batch_* commands are used from the Base transport, then exceptions
                # normally shouldn't reach here.
                @logger.warn(e)
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
                promise.set(Bolt::Result.from_exception(target, error))
              end
            end
          end
          batch_promises.values
        end
      end
    end

    # Create a ResultSet from the results of all promises.
    def await_results(promises)
      ResultSet.new(promises.map(&:value))
    end

    # Execute the given block on a list of nodes in parallel, one thread per "batch".
    #
    # This is the main driver of execution on a list of targets. It first
    # groups targets by transport, then divides each group into batches as
    # defined by the transport. Each batch, along with the corresponding
    # transport, is yielded to the block in turn and the results all collected
    # into a single ResultSet.
    def batch_execute(targets, &block)
      promises = queue_execute(targets, &block)
      await_results(promises)
    end

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

    def report_transport(transport, count)
      name = transport.class.name.split('::').last.downcase
      unless @reported_transports.include?(name)
        @analytics&.event('Transport', 'initialize', label: name, value: count)
      end
      @reported_transports.add(name)
    end

    def report_function_call(function)
      @analytics&.event('Plan', 'call_function', label: function)
    end

    def report_bundled_content(mode, name)
      if @bundled_content&.include?(name)
        @analytics&.event('Bundled Content', mode, label: name)
      end
    end

    def report_apply(statement_count, resource_counts)
      data = { statement_count: statement_count }

      unless resource_counts.empty?
        sum = resource_counts.inject(0) { |accum, i| accum + i }
        # Intentionally rounded to an integer. High precision isn't useful.
        data[:resource_mean] = sum / resource_counts.length
      end

      @analytics&.event('Apply', 'ast', data)
    end

    def report_yaml_plan(plan)
      steps = plan.steps.count
      return_type = case plan.return
                    when Bolt::PAL::YamlPlan::EvaluableString
                      'expression'
                    when nil
                      nil
                    else
                      'value'
                    end

      @analytics&.event('Plan', 'yaml', plan_steps: steps, return_type: return_type)
    rescue StandardError => e
      @logger.debug { "Failed to submit analytics event: #{e.message}" }
    end

    def with_node_logging(description, batch)
      @logger.info("#{description} on #{batch.map(&:uri)}")
      result = yield
      @logger.info(result.to_json)
      result
    end

    def run_command(targets, command, options = {}, &callback)
      description = options.fetch('_description', "command '#{command}'")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }
        options = { '_run_as' => run_as }.merge(options) if run_as

        results = batch_execute(targets) do |transport, batch|
          with_node_logging("Running command '#{command}'", batch) do
            transport.batch_command(batch, command, options, &notify)
          end
        end

        @notifier.shutdown
        results
      end
    end

    def run_script(targets, script, arguments, options = {}, &callback)
      description = options.fetch('_description', "script #{script}")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }
        options = { '_run_as' => run_as }.merge(options) if run_as

        results = batch_execute(targets) do |transport, batch|
          with_node_logging("Running script #{script} with '#{arguments}'", batch) do
            transport.batch_script(batch, script, arguments, options, &notify)
          end
        end

        @notifier.shutdown
        results
      end
    end

    def run_task(targets, task, arguments, options = {}, &callback)
      description = options.fetch('_description', "task #{task.name}")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }
        options = { '_run_as' => run_as }.merge(options) if run_as
        options = options.merge('_load_config' => @load_config)
        arguments['_task'] = task.name

        results = batch_execute(targets) do |transport, batch|
          with_node_logging("Running task #{task.name} with '#{arguments}'", batch) do
            transport.batch_task(batch, task, arguments, options, &notify)
          end
        end

        @notifier.shutdown
        results
      end
    end

    def upload_file(targets, source, destination, options = {}, &callback)
      description = options.fetch('_description', "file upload from #{source} to #{destination}")
      log_action(description, targets) do
        notify = proc { |event| @notifier.notify(callback, event) if callback }
        options = { '_run_as' => run_as }.merge(options) if run_as

        results = batch_execute(targets) do |transport, batch|
          with_node_logging("Uploading file #{source} to #{destination}", batch) do
            transport.batch_upload(batch, source, destination, options, &notify)
          end
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
        batch_execute(targets) do |transport, batch|
          with_node_logging('Waiting until available', batch) do
            begin
              wait_until(wait_time, retry_interval) { transport.batch_connected?(batch) }
              batch.map { |target| Result.new(target) }
            rescue TimeoutError => e
              batch.map { |target| Result.from_exception(target, e) }
            end
          end
        end
      end
    end

    # Used to simplify unit testing, to avoid having to mock other calls to Time.now.
    private def wait_now
      Time.now
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
      transport('pcp').plan_context = plan_context
      @plan_logging = true
    end

    def finish_plan(plan_result)
      transport('pcp').finish_plan(plan_result)
    end

    def without_default_logging
      old_log = @plan_logging
      @plan_logging = false
      yield
    ensure
      @plan_logging = old_log
    end
  end
end
