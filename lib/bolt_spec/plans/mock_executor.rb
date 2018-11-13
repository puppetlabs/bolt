# frozen_string_literal: true

require 'bolt/error'
require 'bolt/result_set'
require 'bolt/result'
require 'set'

module BoltSpec
  module Plans
    class UnexpectedInvocation < ArgumentError; end

    # Nothing in the TaskDouble is 'public'
    class TaskDouble
      def initialize
        @stubs = []
      end

      def process(targets, task, arguments, options)
        # TODO: should we bother matching at all? or just call each
        # stub until one works?
        matches = @stubs.select { |s| s.matches(targets, task, arguments, options) }
        unless matches.empty?
          matches[0].call(targets, task, arguments, options)
        end
      end

      def assert_called(taskname)
        @stubs.each { |s| s.assert_called(taskname) }
      end

      def add_stub
        stub = TaskStub.new
        @stubs.unshift stub
        stub
      end
    end

    class TaskStub
      attr_reader :invocation

      def initialize(expect = false)
        @calls = 0
        @expect = expect
        @expected_calls = 1
        # invocation spec
        @invocation = {}
        # return value
        @data = { default: {} }
      end

      def matches(targets, _task, arguments, options)
        if @invocation[:targets] && Set.new(@invocation[:targets]) != Set.new(targets.map(&:name))
          return false
        end

        if @invocation[:arguments] && arguments != @invocation[:arguments]
          return false
        end

        if @invocation[:options] && options != @invocation[:options]
          return false
        end

        true
      end

      def call(targets, task, arguments, options)
        @calls += 1
        if @return_block
          # Merge arguments and options into params to match puppet function signature.
          result_set = @return_block.call(targets: targets, task: task, params: arguments.merge(options))
          unless result_set.is_a?(Bolt::ResultSet)
            raise "Return block for #{task} did not return a Bolt::ResultSet"
          end
          result_set
        else
          results = targets.map do |target|
            val = @data[target.name] || @data[:default]
            Bolt::Result.new(target, value: val)
          end
          Bolt::ResultSet.new(results)
        end
      end

      def assert_called(taskname)
        satisfied = if @expect
                      (@expected_calls.nil? && @calls > 0) || @calls == @expected_calls
                    else
                      @expected_calls.nil? || @calls <= @expected_calls
                    end
        unless satisfied
          unless (times = @expected_calls)
            times = @expect ? "at least one" : "any number of"
          end
          message = "Expected #{taskname} to be called #{times} times"
          message += " with targets #{@invocation[:targets]}" if @invocation[:targets]
          message += " with parameters #{@invocations[:parameters]}" if @invocation[:parameters]
          raise message
        end
      end

      # This changes the stub from an allow to an expect which will validate
      # that it has been called.
      def expect_call
        @expect = true
        self
      end

      # Below here are the intended 'public' methods of the stub

      # Restricts the stub to only match invocations with
      # the correct targets
      def with_targets(targets)
        targets = [targets] unless targets.is_a? Array
        @invocation[:targets] = targets.map do |target|
          if target.is_a? String
            target
          else
            target.name
          end
        end
        self
      end

      # Restricts the stub to only match invocations with certain parameters
      # All parameters must match exactly and since arguments and options are
      # treated differently at the executor this won't work with some '_*' options
      # TODO: Fix handling of '_*' options probably by breaking them into other helpers
      def with_params(params)
        @invocation[:parameters] = params
        @invocation[:arguments] = params.reject { |k, _v| k.start_with?('_') }
        @invocation[:options] = params.select { |k, _v| k.start_with?('_') }
        self
      end

      # limit the maximum number of times an allow stub may be called or
      # specify how many times an expect stub must be called.
      def be_called_times(times)
        @expected_calls = times
        self
      end

      # error if the stub is called at all.
      def not_be_called
        @expected_calls = 0
        self
      end

      def return(&block)
        raise "Cannot set return values and return block." if @data_set
        @return_block = block
        self
      end

      # Set different result values for each target
      def return_for_targets(data)
        data.each do |target, result|
          raise "Mocked results must be hashes: #{target}: #{result}" unless result.is_a? Hash
        end
        raise "Cannot set return values and return block." if @return_block
        @data = data
        @data_set = true
        self
      end

      # Set a default return value for all targets, specific targets may be overridden with return_for_targets
      def always_return(default_data)
        return_for_targets(default: default_data)
      end

      # Set a default error result for all targets.
      def error_with(error_data)
        always_return("_error" => error_data)
      end
    end

    # Nothing on the executor is 'public'
    class MockExecutor
      attr_reader :noop, :error_message

      def initialize
        @noop = false
        @task_doubles = {}
        @allow_any_task = true
        @error_message = nil
      end

      def run_task(targets, task, arguments, options)
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

      def assert_call_expectations
        @task_doubles.map do |taskname, doub|
          doub.assert_called(taskname)
        end
      end

      def stub_task(task_name)
        @task_doubles[task_name] ||= TaskDouble.new
      end

      def wait_until_available(targets, _options)
        targets.map { |target| Bolt::Result.new(target) }
      end

      def log_plan(_plan_name)
        yield
      end

      def without_default_logging
        yield
      end

      def report_function_call(_function); end

      def report_bundled_content(_mode, _name); end
    end
  end
end
