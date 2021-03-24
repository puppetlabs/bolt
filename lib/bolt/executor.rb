# frozen_string_literal: true

# Used for $ERROR_INFO. This *must* be capitalized!
require 'English'
require 'json'
require 'logging'
require 'pathname'
require 'set'
require 'bolt/analytics'
require 'bolt/result'
require 'bolt/config'
require 'bolt/result_set'
require 'bolt/puppetdb'
# Load transports
require 'bolt/transport/docker'
require 'bolt/transport/local'
require 'bolt/transport/lxd'
require 'bolt/transport/orch'
require 'bolt/transport/podman'
require 'bolt/transport/remote'
require 'bolt/transport/ssh'
require 'bolt/transport/winrm'
require 'bolt/yarn'

module Bolt
  TRANSPORTS = {
    docker: Bolt::Transport::Docker,
    local: Bolt::Transport::Local,
    lxd: Bolt::Transport::LXD,
    pcp: Bolt::Transport::Orch,
    podman: Bolt::Transport::Podman,
    remote: Bolt::Transport::Remote,
    ssh: Bolt::Transport::SSH,
    winrm: Bolt::Transport::WinRM
  }.freeze

  class Executor
    attr_reader :noop, :transports, :in_parallel
    attr_accessor :run_as

    def initialize(concurrency = 1,
                   analytics = Bolt::Analytics::NoopClient.new,
                   noop = false,
                   modified_concurrency = false)
      # lazy-load expensive gem code
      require 'concurrent'
      @analytics = analytics
      @logger = Bolt::Logger.logger(self)

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
      @subscribers = {}
      @publisher = Concurrent::SingleThreadExecutor.new
      @publisher.post { Thread.current[:name] = 'event-publisher' }

      @noop = noop
      @run_as = nil
      @in_parallel = false
      @pool = if concurrency > 0
                Concurrent::ThreadPoolExecutor.new(name: 'exec', max_threads: concurrency)
              else
                Concurrent.global_immediate_executor
              end
      @logger.debug { "Started with #{concurrency} max thread(s)" }

      @concurrency = concurrency
      @warn_concurrency = modified_concurrency
    end

    def transport(transport)
      impl = @transports[transport || 'ssh']
      raise(Bolt::UnknownTransportError, transport) unless impl
      # If there was an error creating the transport, ensure it gets thrown
      impl.no_error!
      impl.value
    end

    def subscribe(subscriber, types = nil)
      @subscribers[subscriber] = types
      self
    end

    def unsubscribe(subscriber, types = nil)
      if types.nil? || types.sort == @subscribers[subscriber]&.sort
        @subscribers.delete(subscriber)
      elsif @subscribers[subscriber].is_a?(Array)
        @subscribers[subscriber] = @subscribers[subscriber] - types
      end
    end

    def publish_event(event)
      @subscribers.each do |subscriber, types|
        # If types isn't set or if the subscriber is subscribed to
        # that type of event, publish the event
        next unless types.nil? || types.include?(event[:type])
        @publisher.post(subscriber) do |sub|
          # Wait for user to input to prompt before printing anything
          sleep(0.1) while @prompting
          sub.handle_event(event)
        end
      end
    end

    def shutdown
      @publisher.shutdown
      @publisher.wait_for_termination
    end

    # Starts executing the given block on a list of nodes in parallel, one thread per "batch".
    #
    # This is the main driver of execution on a list of targets. It first
    # groups targets by transport, then divides each group into batches as
    # defined by the transport. Yields each batch, along with the corresponding
    # transport, to the block in turn and returns an array of result promises.
    def queue_execute(targets)
      if @warn_concurrency && targets.length > @concurrency
        @warn_concurrency = false
        msg = "The ulimit is low, which might cause file limit issues. Default concurrency has been set to "\
              "'#{@concurrency}' to mitigate those issues, which might cause Bolt to run slow. "\
              "Disable this warning by configuring ulimit using 'ulimit -n <limit>' in your shell "\
              "configuration, or by configuring Bolt's concurrency. "\
              "See https://puppet.com/docs/bolt/latest/bolt_known_issues.html for details."
        Bolt::Logger.warn("low_ulimit", msg)
      end

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
            Thread.current[:name] ||= Thread.current.name
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
      publish_event(type: :step_start, description: description, targets: targets)

      start_time = Time.now
      results = yield
      duration = Time.now - start_time

      publish_event(type: :step_finish, description: description, result: results, duration: duration)

      results
    end

    def log_plan(plan_name)
      publish_event(type: :plan_start, plan: plan_name)
      start_time = Time.now

      results = nil
      begin
        results = yield
      ensure
        duration = Time.now - start_time
        publish_event(type: :plan_finish, plan: plan_name, duration: duration)
      end

      results
    end

    private def report_transport(transport, count)
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
      @analytics.report_bundled_content(mode, name)
    end

    def report_file_source(plan_function, source)
      label = Pathname.new(source).absolute? ? 'absolute' : 'module'
      @analytics&.event('Plan', plan_function, label: label)
    end

    def report_apply(statement_count, resource_counts)
      data = { statement_count: statement_count }

      unless resource_counts.empty?
        sum = resource_counts.inject(0) { |accum, i| accum + i }
        # Intentionally rounded to an integer. High precision isn't useful.
        data[:resource_mean] = sum / resource_counts.length
      end

      @analytics&.event('Apply', 'ast', **data)
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
      @logger.trace { "Failed to submit analytics event: #{e.message}" }
    end

    def with_node_logging(description, batch, log_level = :info)
      @logger.send(log_level, "#{description} on #{batch.map(&:safe_name)}")
      publish_event(type: :start_spin)
      result = yield
      publish_event(type: :stop_spin)
      @logger.send(log_level, result.to_json)
      result
    end

    def run_command(targets, command, options = {}, position = [])
      description = options.fetch(:description, "command '#{command}'")
      log_action(description, targets) do
        options[:run_as] = run_as if run_as && !options.key?(:run_as)

        batch_execute(targets) do |transport, batch|
          with_node_logging("Running command '#{command}'", batch) do
            transport.batch_command(batch, command, options, position, &method(:publish_event))
          end
        end
      end
    end

    def run_script(targets, script, arguments, options = {}, position = [])
      description = options.fetch(:description, "script #{script}")
      log_action(description, targets) do
        options[:run_as] = run_as if run_as && !options.key?(:run_as)

        batch_execute(targets) do |transport, batch|
          with_node_logging("Running script #{script} with '#{arguments.to_json}'", batch) do
            transport.batch_script(batch, script, arguments, options, position, &method(:publish_event))
          end
        end
      end
    end

    def run_task(targets, task, arguments, options = {}, position = [], log_level = :info)
      description = options.fetch(:description, "task #{task.name}")
      log_action(description, targets) do
        options[:run_as] = run_as if run_as && !options.key?(:run_as)
        arguments['_task'] = task.name

        batch_execute(targets) do |transport, batch|
          with_node_logging("Running task #{task.name} with '#{arguments.to_json}'", batch, log_level) do
            transport.batch_task(batch, task, arguments, options, position, &method(:publish_event))
          end
        end
      end
    end

    def run_task_with(target_mapping, task, options = {}, position = [])
      targets = target_mapping.keys
      description = options.fetch(:description, "task #{task.name}")

      log_action(description, targets) do
        options[:run_as] = run_as if run_as && !options.key?(:run_as)
        target_mapping.each_value { |arguments| arguments['_task'] = task.name }

        batch_execute(targets) do |transport, batch|
          with_node_logging("Running task #{task.name}'", batch) do
            transport.batch_task_with(batch, task, target_mapping, options, position, &method(:publish_event))
          end
        end
      end
    end

    def upload_file(targets, source, destination, options = {}, position = [])
      description = options.fetch(:description, "file upload from #{source} to #{destination}")
      log_action(description, targets) do
        options[:run_as] = run_as if run_as && !options.key?(:run_as)

        batch_execute(targets) do |transport, batch|
          with_node_logging("Uploading file #{source} to #{destination}", batch) do
            transport.batch_upload(batch, source, destination, options, position, &method(:publish_event))
          end
        end
      end
    end

    def download_file(targets, source, destination, options = {}, position = [])
      description = options.fetch(:description, "file download from #{source} to #{destination}")

      begin
        FileUtils.mkdir_p(destination)
      rescue Errno::EEXIST => e
        message = "#{e.message}; unable to create destination directory #{destination}"
        raise Bolt::Error.new(message, 'bolt/file-exist-error')
      end

      log_action(description, targets) do
        options[:run_as] = run_as if run_as && !options.key?(:run_as)

        batch_execute(targets) do |transport, batch|
          with_node_logging("Downloading file #{source} to #{destination}", batch) do
            transport.batch_download(batch, source, destination, options, position, &method(:publish_event))
          end
        end
      end
    end

    def run_plan(scope, plan, params)
      plan.call_by_name_with_scope(scope, params, true)
    end

    def create_yarn(scope, block, object, index)
      fiber = Fiber.new do
        # Create the new scope
        newscope = Puppet::Parser::Scope.new(scope.compiler)
        local = Puppet::Parser::Scope::LocalScope.new

        # Compress the current scopes into a single vars hash to add to the new scope
        current_scope = scope.effective_symtable(true)
        until current_scope.nil?
          current_scope.instance_variable_get(:@symbols)&.each_pair { |k, v| local[k] = v }
          current_scope = current_scope.parent
        end
        newscope.push_ephemerals([local])

        begin
          result = catch(:return) do
            args = { block.parameters[0][1].to_s => object }
            block.closure.call_by_name_with_scope(newscope, args, true)
          end

          # If we got a return from the block, get it's value
          # Otherwise the result is the last line from the block
          result = result.value if result.is_a?(Puppet::Pops::Evaluator::Return)

          # Validate the result is a PlanResult
          unless Puppet::Pops::Types::TypeParser.singleton.parse('Boltlib::PlanResult').instance?(result)
            raise Bolt::InvalidParallelResult.new(result.to_s, *Puppet::Pops::PuppetStack.top_of_stack)
          end

          result
        rescue Puppet::PreformattedError => e
          if e.cause.is_a?(Bolt::Error)
            e.cause
          else
            raise e
          end
        end
      end

      Bolt::Yarn.new(fiber, index)
    end

    def handle_event(event)
      case event[:type]
      when :node_result
        @thread_completed = true
      end
    end

    def round_robin(skein)
      subscribe(self, [:node_result])
      results = Array.new(skein.length)
      @in_parallel = true
      publish_event(type: :stop_spin)

      until skein.empty?
        @thread_completed = false
        r = nil

        skein.each do |yarn|
          if yarn.alive?
            publish_event(type: :stop_spin)
            r = yarn.resume
          else
            results[yarn.index] = yarn.value
            skein.delete(yarn)
          end
        end

        next unless r == 'unfinished'
        sleep(0.1) until @thread_completed || skein.empty?
      end

      publish_event(type: :stop_spin)
      @in_parallel = false
      unsubscribe(self, [:node_result])
      results
    end

    class TimeoutError < RuntimeError; end

    def wait_until_available(targets,
                             description: 'wait until available',
                             wait_time: 120,
                             retry_interval: 1)
      log_action(description, targets) do
        batch_execute(targets) do |transport, batch|
          with_node_logging('Waiting until available', batch) do
            wait_until(wait_time, retry_interval) { transport.batch_connected?(batch) }
            batch.map { |target| Result.new(target, action: 'wait_until_available', object: description) }
          rescue TimeoutError => e
            available, unavailable = batch.partition { |target| transport.batch_connected?([target]) }
            (
              available.map { |target| Result.new(target, action: 'wait_until_available', object: description) } +
              unavailable.map { |target| Result.from_exception(target, e, action: 'wait_until_available') }
            )
          end
        end
      end
    end

    # Used to simplify unit testing, to avoid having to mock other calls to Time.now.
    private def wait_now
      Time.now
    end

    private def wait_until(timeout, retry_interval)
      start = wait_now
      until yield
        raise(TimeoutError, 'Timed out waiting for target') if (wait_now - start).to_i >= timeout
        sleep(retry_interval)
      end
    end

    def prompt(prompt, options)
      unless $stdin.tty?
        return options[:default] if options[:default]
        raise Bolt::Error.new('STDIN is not a tty, unable to prompt', 'bolt/no-tty-error')
      end

      @prompting = true

      if options[:default] && !options[:sensitive]
        $stderr.print("#{prompt} [#{options[:default]}]: ")
      else
        $stderr.print("#{prompt}: ")
      end

      value = if options[:sensitive]
                $stdin.noecho(&:gets).to_s.chomp
              else
                $stdin.gets.to_s.chomp
              end

      @prompting = false

      $stderr.puts if options[:sensitive]

      value = options[:default] if value.empty?
      value
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
    end

    def finish_plan(plan_result)
      transport('pcp').finish_plan(plan_result)
    end

    def without_default_logging
      publish_event(type: :disable_default_output)
      yield
    ensure
      publish_event(type: :enable_default_output)
    end
  end
end
