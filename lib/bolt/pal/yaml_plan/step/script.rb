# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Script < Step
          def self.allowed_keys
            super + Set['arguments']
          end

          def self.option_keys
            Set['catch_errors', 'env_vars', 'run_as']
          end

          def self.required_keys
            Set['script', 'targets']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          private def format_args(body)
            opts = format_options(body)
            opts = opts.merge('arguments' => body['arguments'] || []) if body.key?('arguments')

            args = [body['script'], body['targets']]
            args << body['description'] if body['description']
            args << opts if opts.any?

            args
          end

          # Returns the function corresponding to the step
          #
          private def function
            'run_script'
          end
        end
      end
    end
  end
end
