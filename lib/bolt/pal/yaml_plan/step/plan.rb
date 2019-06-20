# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Plan < Step
          def self.allowed_keys
            super + Set['plan', 'parameters']
          end

          def self.required_keys
            Set.new
          end

          def initialize(step_body)
            super
            @plan = step_body['plan']
            @parameters = step_body.fetch('parameters', {})
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            fn = 'run_plan'
            args = [@plan]
            args << @parameters unless @parameters.empty?

            code << function_call(fn, args)

            code << "\n"
          end
        end
      end
    end
  end
end
