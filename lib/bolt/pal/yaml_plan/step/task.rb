# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Task < Step
          def self.allowed_keys
            super + Set['task', 'parameters']
          end

          def self.required_keys
            Set['target']
          end

          def initialize(step_body)
            super
            @task = step_body['task']
            @parameters = step_body.fetch('parameters', {})
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            fn = 'run_task'
            args = [@task, @target]
            args << @description if @description
            args << @parameters unless @parameters.empty?

            code << function_call(fn, args)

            code << "\n"
          end
        end
      end
    end
  end
end
