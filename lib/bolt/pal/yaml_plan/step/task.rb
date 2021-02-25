# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Task < Step
          def self.allowed_keys
            super + Set['parameters']
          end

          def self.option_keys
            Set['catch_errors', 'noop', 'run_as']
          end

          def self.required_keys
            Set['targets', 'task']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          def args
            params = (@body['parameters'] || {}).merge(options)

            args = [@body['task'], @body['targets']]
            args << @body['description'] if @body['description']
            args << params if params.any?

            args
          end

          # Transpiles the step into the plan language
          #
          def transpile
            code = String.new("  ")
            code << "$#{@body['name']} = " if @body['name']
            code << function_call('run_task', args)
            code << "\n"
          end
        end
      end
    end
  end
end
