# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Script < Step
          def self.allowed_keys
            super + Set['arguments', 'pwsh_params']
          end

          def self.option_keys
            Set['catch_errors', 'env_vars', 'run_as']
          end

          def self.required_keys
            Set['script', 'targets']
          end

          def self.validate_step_keys(body, number)
            super

            if body.key?('arguments') && !body['arguments'].nil? && !body['arguments'].is_a?(Array)
              raise StepError.new('arguments key must be an array', body['name'], number)
            end

            if body.key?('pwsh_params') && !body['pwsh_params'].nil? && !body['pwsh_params'].is_a?(Hash)
              raise StepError.new('pwsh_params key must be a hash', body['name'], number)
            end

            if body.key?('env_vars') && ![Hash, String].include?(body['env_vars'].class)
              raise StepError.new('env_vars key must be a hash or evaluable string', body['name'], number)
            end
          end

          # Returns an array of arguments to pass to the step's function call
          #
          private def format_args(body)
            args        = body['arguments'] || []
            pwsh_params = body['pwsh_params'] || {}

            opts = format_options(body)
            opts = opts.merge('arguments' => args) if args.any?
            opts = opts.merge('pwsh_params' => pwsh_params) if pwsh_params.any?

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
