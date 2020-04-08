# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Command < Step
          def self.allowed_keys
            super + Set['command']
          end

          def self.required_keys
            Set['targets']
          end

          def initialize(step_body)
            super
            @command = step_body['command']
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            fn = 'run_command'
            args = [@command, @targets]
            args << @description if @description

            code << function_call(fn, args)

            code << "\n"
          end
        end
      end
    end
  end
end
