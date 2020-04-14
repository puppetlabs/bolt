# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Script < Step
          def self.allowed_keys
            super + Set['script', 'parameters', 'arguments']
          end

          def self.required_keys
            Set['targets']
          end

          def initialize(step_body)
            super
            @script = step_body['script']
            @parameters = step_body.fetch('parameters', {})
            @arguments = step_body.fetch('arguments', [])
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            options = @parameters.dup
            options['arguments'] = @arguments unless @arguments.empty?

            fn = 'run_script'
            args = [@script, @targets]
            args << @description if @description
            args << options unless options.empty?

            code << function_call(fn, args)

            code << "\n"
          end
        end
      end
    end
  end
end
