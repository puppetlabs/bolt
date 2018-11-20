# frozen_string_literal: true

require 'bolt_spec/plans/action_stubs'
require 'bolt/error'
require 'bolt/result_set'
require 'bolt/result'
require 'pathname'
require 'set'

module BoltSpec
  module Plans
    MOCKED_ACTIONS = %i[command script task upload].freeze

    class UnexpectedInvocation < ArgumentError; end

    # Nothing on the executor is 'public'
    class MockExecutor
      attr_reader :noop, :error_message
      attr_accessor :run_as

      def initialize(modulepath)
        @noop = false
        @run_as = nil
        @error_message = nil
        @allow_apply = false
        @modulepath = [modulepath].flatten.map { |path| File.absolute_path(path) }
        MOCKED_ACTIONS.each { |action| instance_variable_set(:"@#{action}_doubles", {}) }
      end

      def module_file_id(file)
        modpath = @modulepath.select { |path| file =~ /^#{path}/ }
        raise "Could not identify module path containing #{file}: #{modpath}" unless modpath.size == 1

        path = Pathname.new(file)
        relative = path.relative_path_from(Pathname.new(modpath.first))
        segments = relative.to_path.split('/')
        ([segments[0]] + segments[2..-1]).join('/')
      end

      def run_command(targets, command, options = {})
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

      def run_script(targets, script_path, arguments, options = {})
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

      def run_task(targets, task, arguments, options = {})
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

      def upload_file(targets, source_path, destination, options = {})
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

      def assert_call_expectations
        MOCKED_ACTIONS.each do |action|
          instance_variable_get(:"@#{action}_doubles").map do |object, doub|
            doub.assert_called(object)
          end
        end
      end

      MOCKED_ACTIONS.each do |action|
        define_method(:"stub_#{action}") do |object|
          instance_variable_get(:"@#{action}_doubles")[object] ||= ActionDouble.new(:"#{action.capitalize}Stub")
        end
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

      def report_function_call(_function); end

      def report_bundled_content(_mode, _name); end

      def analytics; end

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
        Bolt::ResultSet.new(promises.map { |target| Bolt::Result.new(target) })
      end
    end
  end
end
