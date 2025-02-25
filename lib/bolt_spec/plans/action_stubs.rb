# frozen_string_literal: true

require 'bolt/plan_result'
require 'bolt/result'
require 'bolt/util'

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

      def add_stub(inventory = nil)
        stub = Plans.const_get(@action_stub).new(false, inventory)
        @stubs.unshift stub
        stub
      end
    end

    class ActionStub
      attr_reader :invocation

      def initialize(expect = false, inventory = nil)
        @calls = 0
        @expect = expect
        @expected_calls = nil
        # invocation spec
        @invocation = {}
        # return value
        @data = { default: {} }
        @inventory = inventory
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
          if parameters
            # Print the parameters hash by converting it to JSON and then re-parsing.
            # This prevents issues in Bolt data types, such as Targets, from generating
            # gigantic, unreadable, data when converted to string by interpolation.
            # Targets exhibit this behavior because they have a reference to @inventory.
            # When the target is converted into a string, it converts the full Inventory
            # into a string recursively.
            parameters_str = JSON.parse(parameters.to_json)
            message += " with parameters #{parameters_str}"
          end
          raise message
        end
      end

      # This changes the stub from an allow to an expect which will validate
      # that it has been called.
      def expect_call
        @expected_calls = 1
        @expect = true
        self
      end

      # Used to create a valid Bolt::Result object from result data.
      def default_for(target)
        case @data[:default]
        when Bolt::PlanFailure
          # Bolt::PlanFailure needs to be declared before Bolt::Error because
          # Bolt::PlanFailure is an instance of Bolt::Error, so it can match both
          # in this case we need to treat Bolt::PlanFailure's in a different way
          #
          # raise Bolt::PlanFailure errors so that the PAL can catch them and wrap
          # them into Bolt::PlanResult's for us.
          raise @data[:default]
        when Bolt::Error
          Bolt::Result.from_exception(target, @data[:default])
        when Hash
          result_for(target, **Bolt::Util.walk_keys(@data[:default], &:to_sym))
        else
          raise 'Default result must be a Hash'
        end
      end

      def check_resultset(result_set, object)
        unless result_set.is_a?(Bolt::ResultSet)
          raise "Return block for #{object} did not return a Bolt::ResultSet"
        end
        result_set
      end

      def check_plan_result(plan_result, plan_clj)
        unless plan_result.is_a?(Bolt::PlanResult)
          raise "Return block for #{plan_clj.closure_name} did not return a Bolt::PlanResult"
        end
        plan_result
      end

      # Below here are the intended 'public' methods of the stub

      # Restricts the stub to only match invocations with
      # the correct targets
      def with_targets(targets)
        targets = Array(targets)
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

      # Set different result values for each target. May use string or symbol keys, but allowed key names
      # are restricted based on action.
      def return_for_targets(data)
        data.each_with_object(@data) do |(target, result), hsh|
          raise "Mocked results must be hashes: #{target}: #{result}" unless result.is_a? Hash
          # set the inventory from the BoltSpec::Plans, otherwise if we try to convert
          # this target to a string, it will fail to string conversion because the
          # inventory is nil
          hsh[target] = result_for(Bolt::Target.new(target, @inventory), **Bolt::Util.walk_keys(result, &:to_sym))
        end
        raise "Cannot set return values and return block." if @return_block
        @data_set = true
        self
      end

      # Set a default return value for all targets, specific targets may be overridden with return_for_targets.
      # Follows the same rules for data as return_for_targets.
      def always_return(data)
        @data[:default] = data
        @data_set = true
        self
      end

      # Set a default error result for all targets.
      def error_with(data, clazz = Bolt::Error)
        data = Bolt::Util.walk_keys(data, &:to_s)
        if data['msg'] && data['kind'] && (data.keys - %w[msg kind details issue_code]).empty?
          @data[:default] = clazz.new(data['msg'], data['kind'], data['details'], data['issue_code'])
        else
          $stderr.puts "In the future 'error_with()' might require msg and kind, and " \
                       "optionally accept only details and issue_code."
          @data[:default] = data
        end
        @data_set = true
        self
      end
    end
  end
end

require_relative 'action_stubs/command_stub'
require_relative 'action_stubs/plan_stub'
require_relative 'action_stubs/script_stub'
require_relative 'action_stubs/task_stub'
require_relative 'action_stubs/upload_stub'
require_relative 'action_stubs/download_stub'
