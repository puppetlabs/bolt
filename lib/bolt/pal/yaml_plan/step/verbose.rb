# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Verbose < Step
          def self.allowed_keys
            super + Set['verbose']
          end

          def self.required_keys
            Set['verbose']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          private def format_args(body)
            [body['verbose']]
          end

          # Returns the function corresponding to the step
          #
          private def function
            'out::verbose'
          end
        end
      end
    end
  end
end
