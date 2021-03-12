# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Prompt < Step
          def self.allowed_keys
            super + Set['default', 'menu', 'sensitive']
          end

          def self.required_keys
            Set['prompt']
          end

          def self.validate_step_keys(body, number)
            super

            if body.key?('menu') && ![Array, Hash].include?(body['menu'].class)
              raise StepError.new("Menu key must be an array or hash", body['name'], number)
            end
          end

          # Returns an array of arguments to pass to the step's function call
          #
          private def format_args(body)
            args = [body['prompt']]

            if body['menu']
              opts = body.slice('default').compact
              args << body['menu']
            else
              opts = body.slice('default', 'sensitive').compact
            end

            args << opts if opts.any?
            args
          end

          # Returns the function corresponding to the step
          #
          private def function
            body['menu'] ? 'prompt::menu' : 'prompt'
          end
        end
      end
    end
  end
end
