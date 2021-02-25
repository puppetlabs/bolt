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
          def args
            opts = options
            opts = opts.merge('arguments' => @body['arguments'] || []) if @body.key?('arguments')

            args = [@body['script'], @body['targets']]
            args << @body['description'] if @body['description']
            args << opts if opts.any?

            args
          end

          # Transpiles the step into the plan language
          #
          def transpile
            code = String.new("  ")
            code << "$#{@body['name']} = " if @body['name']
            code << function_call('run_script', args)
            code << "\n"
          end
        end
      end
    end
  end
end
