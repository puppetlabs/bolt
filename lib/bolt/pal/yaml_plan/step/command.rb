# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Command < Step
          def self.option_keys
            Set['catch_errors', 'env_vars', 'run_as']
          end

          def self.required_keys
            Set['command', 'targets']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          private def format_args(body)
            opts = format_options(body)

            args = [body['command'], body['targets']]
            args << body['description'] if body['description']
            args << opts if opts.any?

            args
          end

          # Returns the function corresponding to the step
          #
          private def function
            'run_command'
          end
        end
      end
    end
  end
end
