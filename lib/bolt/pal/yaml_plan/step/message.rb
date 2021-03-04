# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Message < Step
          def self.allowed_keys
            super + Set['message']
          end

          def self.required_keys
            Set['message']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          private def format_args(body)
            [body['message']]
          end

          # Returns the function corresponding to the step
          #
          private def function
            'out::message'
          end

          # Transpiles the step into the plan language
          #
          def transpile
            code = String.new("  ")
            code << function_call(function, format_args(body))
            code << "\n"
          end
        end
      end
    end
  end
end
