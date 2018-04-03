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
    attr_accessor :run_as

    def initialize(config = Bolt::Config.new, noop = nil, plan_logging = false)
      @config = config
      @logger = Logging.logger[self]

      @transports = Bolt::TRANSPORTS.each_with_object({}) do |(key, val), coll|
        coll[key.to_s] = Concurrent::Delay.new { val.new }
      end

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
      impl = @transports[transport || 'ssh']
      # If there was an error creating the transport, ensure it gets thrown
      impl.no_error!
      impl.value
    end

    def summary(description, result)
      fc = result.error_set.length
      npl = result.length == 1 ? '' : 's'
      fpl = fc == 1 ? '' : 's'
      "Finished: #{description} on #{result.length} node#{npl} with #{fc} failure#{fpl}"
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

    def run_command(targets, command, options = {}, &callback)
      description = options.fetch('_description', "command '#{command}'")
      @logger.info("Starting: #{description} on #{targets.map(&:uri)}")
      @logger.debug("Running command '#{command}' on #{targets.map(&:uri)}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_command(batch, command, options, &notify)
      end

      @logger.info(summary(description, results))
      @notifier.shutdown
      results
    end

    def run_script(targets, script, arguments, options = {}, &callback)
      description = options.fetch('_description', "script #{script}")
      @logger.info("Starting: #{description} on #{targets.map(&:uri)}")
      @logger.debug("Running script #{script} with '#{arguments}' on #{targets.map(&:uri)}")

      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_script(batch, script, arguments, options, &notify)
      end

      @logger.info(summary(description, results))
      @notifier.shutdown
      results
    end

    def run_task(targets, task, arguments, options = {}, &callback)
      description = options.fetch('_description', "task #{task.name}")
      @logger.info("Starting: #{description} on #{targets.map(&:uri)}")
      @logger.debug("Running task #{task.name} with '#{arguments}' via #{task.input_method} on #{targets.map(&:uri)}")

      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_task(batch, task, arguments, options, &notify)
      end

      @logger.info(summary(description, results))
      @notifier.shutdown
      results
    end

    def file_upload(targets, source, destination, options = {}, &callback)
      description = options.fetch('_description', "file upload from #{source} to #{destination}")
      @logger.info("Starting: #{description} on #{targets.map(&:uri)}")
      notify = proc { |event| @notifier.notify(callback, event) if callback }
      options = { '_run_as' => run_as }.merge(options) if run_as

      results = batch_execute(targets) do |transport, batch|
        transport.batch_upload(batch, source, destination, options, &notify)
      end

      @logger.info(summary(description, results))
      @notifier.shutdown
      results
    end

    def puppetdb_client
      return @puppetdb_client if @puppetdb_client
      puppetdb_config = Bolt::PuppetDB::Config.new(nil, @config.puppetdb)
      @puppetdb_client = Bolt::PuppetDB::Client.from_config(puppetdb_config)
    end

    def puppetdb_fact(certnames)
      puppetdb_client.facts_for_node(certnames)
    rescue StandardError => e
      raise Bolt::CLIError, "Could not retrieve targets from PuppetDB: #{e}"
    end
  end
end
