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
          private def format_args(body)
            opts   = format_options(body)
            params = (body['parameters'] || {}).merge(opts)

            args = [body['task'], body['targets']]
            args << body['description'] if body['description']
            args << params if params.any?

            args
          end

          # Returns the function corresponding to the step
          #
          private def function
            'run_task'
          end
        end
      end
    end
  end
end
