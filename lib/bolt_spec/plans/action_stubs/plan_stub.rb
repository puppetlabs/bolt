# frozen_string_literal: true

module BoltSpec
  module Plans
    class PlanStub < ActionStub
      def matches(_scope, _plan, params)
        targets = params.fetch('nodes', params.fetch('targets', nil))
        if @invocation[:targets] && Set.new(@invocation[:targets]) != Set.new(targets)
          return false
        end

        if @invocation[:params] && params != @invocation[:params]
          return false
        end

        true
      end

      def call(_scope, plan, params)
        @calls += 1
        if @return_block
          check_plan_result(@return_block.call(plan: plan, params: params), plan)
        else
          default_for(nil)
        end
      end

      def parameters
        @invocation[:params]
      end

      # Allow any data.
      def result_for(_target, data)
        Bolt::PlanResult.new(Bolt::Util.walk_keys(data, &:to_s), 'success')
      end

      # Public methods

      # Restricts the stub to only match invocations with certain parameters.
      # All parameters must match exactly.
      def with_params(params)
        @invocation[:params] = params
        self
      end

      def return_for_targets(_data)
        raise "return_for_targets is not implemented for plan spec tests (allow_plan, expect_plan, allow_any_plan, etc)"
      end

      def error_with(data, clazz = Bolt::PlanFailure)
        super(data, clazz)
      end
    end
  end
end
