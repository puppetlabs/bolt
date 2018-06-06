# frozen_string_literal: true

# Used for $ERROR_INFO. This *must* be capitalized!
require 'English'
require 'json'
require 'concurrent'
require 'logging'
require 'bolt/result'
require 'bolt/config'
require 'bolt/notifier'
require 'bolt/result_set'
require 'bolt/puppetdb'

module Bolt
  class Executor
    attr_reader :noop, :transports
    attr_accessor :run_as, :plan_logging

    def initialize(config = Bolt::Config.new, noop = nil)
      @config = config
      @logger = Logging.logger[self]
      @plan_logging = false

      @transports = Bolt::TRANSPORTS.each_with_object({}) do |(key, val), coll|
        coll[key.to_s] = Concurrent::Delay.new { val.new }
      end

      @noop = noop
      @run_as = nil
      @pool = Concurrent::ThreadPoolExecutor.new(max_threads: @config[:concurrency])
      @logger.debug { "Started with #{@config[:concurrency]} max thread(s)" }
      @notifier = Bolt::Notifier.new
    end

    def transport(transport)
      impl = @transports[transport || 'ssh']
      raise(Bolt::UnknownTransportError, transport) unless impl
      # If there was an error creating the transport, ensure it gets thrown
      impl.no_error!
      impl.value
    end

    # Execute the given block on a list of nodes in parallel, one thread per "batch".
    #
    # This is the main driver of execution on a list of targets. It first
    # groups targets by transport, then divides each group into batches as
    # defined by the transport. Each batch, along with the corresponding
    # transport, is yielded to the block in turn and the results all collected
    # into a single ResultSet.
    def batch_execute(targets)
      promises = targets.group_by(&:protocol).flat_map do |protocol, protocol_targets|
        transport = transport(protocol)
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
                promise.set(Bolt::Result.from_exception(target, error))
              end
            end
          end
          batch_promises.values
        end
      end
      ResultSet.new(promises.map(&:value))
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
    private :log_action

    def with_node_logging(description, batch)
      @logger.info("#{description} on #{batch.map(&:uri)}")
      result = yield
      @logger.info(result.to_json)
      result
    end
    private :with_node_logging

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

        results = batch_execute(targets) do |transport, batch|
          with_node_logging("Running task #{task.name} with '#{arguments}' via #{task.input_method}", batch) do
            transport.batch_task(batch, task, arguments, options, &notify)
          end
        end

        @notifier.shutdown
        results
      end
    end

    def file_upload(targets, source, destination, options = {}, &callback)
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
  end
end
