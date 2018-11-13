# frozen_string_literal: true

module BoltSpec
  module Plans
    # Nothing in the ActionDouble is 'public'
    class ActionDouble
      def initialize(action_stub)
        @stubs = []
        @action_stub = action_stub
      end

      def process(*args)
        matches = @stubs.select { |s| s.matches(*args) }
        unless matches.empty?
          matches[0].call(*args)
        end
      end

      def assert_called(object)
        @stubs.each { |s| s.assert_called(object) }
      end

      def add_stub
        stub = Plans.const_get(@action_stub).new
        @stubs.unshift stub
        stub
      end
    end

    class ActionStub
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

      def assert_called(object)
        satisfied = if @expect
                      (@expected_calls.nil? && @calls > 0) || @calls == @expected_calls
                    else
                      @expected_calls.nil? || @calls <= @expected_calls
                    end
        unless satisfied
          unless (times = @expected_calls)
            times = @expect ? "at least one" : "any number of"
          end
          message = "Expected #{object} to be called #{times} times"
          message += " with targets #{@invocation[:targets]}" if @invocation[:targets]
          message += " with parameters #{parameters}" if parameters
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
  end
end

require_relative 'action_stubs/command_stub'
require_relative 'action_stubs/script_stub'
require_relative 'action_stubs/task_stub'
require_relative 'action_stubs/upload_stub'
