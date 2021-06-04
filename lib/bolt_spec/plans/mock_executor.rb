# frozen_string_literal: true

require 'bolt_spec/plans/action_stubs'
require 'bolt_spec/plans/publish_stub'
require 'bolt/error'
require 'bolt/executor'
require 'bolt/result_set'
require 'bolt/result'
require 'pathname'
require 'set'

module BoltSpec
  module Plans
    MOCKED_ACTIONS = %i[command download plan script task upload].freeze

    class UnexpectedInvocation < ArgumentError; end

    # Nothing on the executor is 'public'
    class MockExecutor
      attr_reader :noop, :error_message, :transports, :future
      attr_accessor :run_as, :transport_features, :execute_any_plan

      def initialize(modulepath)
        @noop = false
        @run_as = nil
        @future = {}
        @error_message = nil
        @allow_apply = false
        @modulepath = [modulepath].flatten.map { |path| File.absolute_path(path) }
        MOCKED_ACTIONS.each { |action| instance_variable_set(:"@#{action}_doubles", {}) }
        @stub_out_message = nil
        @transport_features = ['puppet-agent']
        @executor_real = Bolt::Executor.new
        # by default, we want to execute any plan that we come across without error
        # or mocking. users can toggle this behavior so that plans will either need to
        # be mocked out, or an error will be thrown.
        @execute_any_plan = true
        # plans that are allowed to be executed by the @executor_real
        @allowed_exec_plans = {}
        @id = 0
      end

      def module_file_id(file)
        modpath = @modulepath.select { |path| file =~ /^#{path}/ }
        raise "Could not identify modulepath containing #{file}: #{modpath}" unless modpath.size == 1

        path = Pathname.new(file)
        relative = path.relative_path_from(Pathname.new(modpath.first))
        segments = relative.to_path.split('/')
        ([segments[0]] + segments[2..-1]).join('/')
      end

      def run_command(targets, command, options = {}, _position = [])
        result = nil
        if (doub = @command_doubles[command] || @command_doubles[:default])
          result = doub.process(targets, command, options)
        end
        unless result
          targets = targets.map(&:name)
          @error_message = "Unexpected call to 'run_command(#{command}, #{targets}, #{options})'"
          raise UnexpectedInvocation, @error_message
        end
        result
      end

      def run_script(targets, script_path, arguments, options = {}, _position = [])
        script = module_file_id(script_path)
        result = nil
        if (doub = @script_doubles[script] || @script_doubles[:default])
          result = doub.process(targets, script, arguments, options)
        end
        unless result
          targets = targets.map(&:name)
          params = options.merge('arguments' => arguments)
          @error_message = "Unexpected call to 'run_script(#{script}, #{targets}, #{params})'"
          raise UnexpectedInvocation, @error_message
        end
        result
      end

      def run_task(targets, task, arguments, options = {}, _position = [])
        result = nil
        if (doub = @task_doubles[task.name] || @task_doubles[:default])
          result = doub.process(targets, task.name, arguments, options)
        end
        unless result
          targets = targets.map(&:name)
          params = arguments.merge(options)
          @error_message = "Unexpected call to 'run_task(#{task.name}, #{targets}, #{params})'"
          raise UnexpectedInvocation, @error_message
        end
        result
      end

      def run_task_with(target_mapping, task, options = {}, _position = [])
        resultsets = target_mapping.map do |target, arguments|
          run_task([target], task, arguments, options)
        end.compact

        Bolt::ResultSet.new(resultsets.map(&:results).flatten)
      end

      def download_file(targets, source, destination, options = {}, _position = [])
        result = nil
        if (doub = @download_doubles[source] || @download_doubles[:default])
          result = doub.process(targets, source, destination, options)
        end
        unless result
          targets = targets.map(&:name)
          @error_message = "Unexpected call to 'download_file(#{source}, #{destination}, #{targets}, #{options})'"
          raise UnexpectedInvocation, @error_message
        end
        result
      end

      def upload_file(targets, source_path, destination, options = {}, _position = [])
        source = module_file_id(source_path)
        result = nil
        if (doub = @upload_doubles[source] || @upload_doubles[:default])
          result = doub.process(targets, source, destination, options)
        end
        unless result
          targets = targets.map(&:name)
          @error_message = "Unexpected call to 'upload_file(#{source}, #{destination}, #{targets}, #{options})'"
          raise UnexpectedInvocation, @error_message
        end
        result
      end

      def with_plan_allowed_exec(plan_name, params)
        @allowed_exec_plans[plan_name] = params
        result = yield
        @allowed_exec_plans.delete(plan_name)
        result
      end

      def run_plan(scope, plan_clj, params)
        result = nil
        plan_name = plan_clj.closure_name

        # get the mock object either by plan name, or the default in case allow_any_plan
        # was called, if both are nil / don't exist, then dub will be nil and we'll fall
        # through to another conditional statement
        doub = @plan_doubles[plan_name] || @plan_doubles[:default]

        # rubocop:disable Lint/DuplicateBranch
        # High level:
        #  - If we've explicitly allowed execution of the plan (normally the main plan
        #    passed into BoltSpec::Plan::run_plan()), then execute it
        #  - If we've explicitly "allowed/expected" the plan (mocked),
        #    then run it through the mock object
        #  - If we're allowing "any" plan to be executed,
        #    then execute it
        #  - Otherwise we have an error
        if @allowed_exec_plans.key?(plan_name) && @allowed_exec_plans[plan_name] == params
          # This plan's name + parameters were explicitly allowed to be executed.
          # run it with the real executor.
          # We require this functionality so that the BoltSpec::Plans.run_plan()
          # function can kick off the initial plan. In reality, no other plans should
          # be in this hash.
          result = @executor_real.run_plan(scope, plan_clj, params)
        elsif doub
          result = doub.process(scope, plan_clj, params)
          # the throw here is how Puppet exits out of a closure and returns a result
          # it throws this special symbol with a result object that is captured by
          # the run_plan Puppet function
          throw :return, result
        elsif @execute_any_plan
          # if the plan wasn't allowed or mocked out, and we're allowing any plan to be
          # executed, then execute the plan
          result = @executor_real.run_plan(scope, plan_clj, params)
        else
          # convert to JSON and back so that we get the ruby representation with all keys and
          # values converted to a string .to_s instead of their ruby object notation
          params_str = JSON.parse(params.to_json)
          @error_message = "Unexpected call to 'run_plan(#{plan_name}, #{params_str})'"
          raise UnexpectedInvocation, @error_message
        end
        # rubocop:enable Lint/DuplicateBranch
        result
      end

      def assert_call_expectations
        MOCKED_ACTIONS.each do |action|
          instance_variable_get(:"@#{action}_doubles").map do |object, doub|
            doub.assert_called(object)
          end
        end
        @stub_out_message.assert_called('out::message') if @stub_out_message
      end

      MOCKED_ACTIONS.each do |action|
        define_method(:"stub_#{action}") do |object|
          instance_variable_get(:"@#{action}_doubles")[object] ||= ActionDouble.new(:"#{action.capitalize}Stub")
        end
      end

      def stub_out_message
        @stub_out_message ||= ActionDouble.new(:PublishStub)
      end

      def stub_apply
        @allow_apply = true
      end

      def wait_until_available(targets, _options)
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.new(target) })
      end

      def log_action(*_args)
        yield
      end

      def log_plan(_plan_name)
        yield
      end

      def without_default_logging
        yield
      end

      def publish_event(event)
        if event[:type] == :message
          unless @stub_out_message
            @error_message = "Unexpected call to 'out::message(#{event[:message]})'"
            raise UnexpectedInvocation, @error_message
          end
          @stub_out_message.process(event[:message])
        end
      end

      # Mocked for Apply so it does not compile and execute.
      def with_node_logging(_description, targets)
        raise "Unexpected call to apply(#{targets})" unless @allow_apply
      end

      def queue_execute(targets)
        raise "Unexpected call to apply(#{targets})" unless @allow_apply
        targets
      end

      def await_results(promises)
        raise "Unexpected call to apply(#{targets})" unless @allow_apply
        Bolt::ResultSet.new(promises.map { |target| Bolt::ApplyResult.new(target) })
      end
      # End Apply mocking

      # Mocked for apply_prep
      def transport(_protocol)
        Class.new do
          attr_reader :provided_features

          def initialize(features)
            @provided_features = features
          end
        end.new(transport_features)
      end
      # End apply_prep mocking

      # Parallel function mocking
      def run_in_thread
        yield
      end

      def in_parallel?
        false
      end

      def create_future(scope: nil, name: nil)
        newscope = nil
        if scope
          # Create the new scope
          newscope = Puppet::Parser::Scope.new(scope.compiler)
          local = Puppet::Parser::Scope::LocalScope.new

          # Compress the current scopes into a single vars hash to add to the new scope
          scope.to_hash(true, true).each_pair { |k, v| local[k] = v }
          newscope.push_ephemerals([local])
        end

        # Execute "futures" serially when running in BoltSpec
        result = yield newscope
        @id += 1
        future = Bolt::PlanFuture.new(nil, @id, name: name)
        future.value = result
        future
      end

      def wait(results, _timeout, **_kwargs)
        results
      end

      # Since Futures are executed immediately once created, this will always
      # be true by the time it's called.
      def plan_complete?
        true
      end

      def plan_futures
        []
      end

      # Public methods on Bolt::Executor that need to be mocked so there aren't
      # "undefined method" errors.

      def batch_execute(_targets); end

      def finish_plan(_plan_result); end

      def handle_event(_event); end

      def prompt(_prompt, _options); end

      def report_function_call(_function); end

      def report_bundled_content(_mode, _name); end

      def report_file_source(_plan_function, _source); end

      def report_apply(_statements, _resources); end

      def report_yaml_plan(_plan); end

      def shutdown; end

      def start_plan(_plan_context); end

      def subscribe(_subscriber, _types = nil); end

      def unsubscribe(_subscriber, _types = nil); end

      def round_robin; end
    end
  end
end
