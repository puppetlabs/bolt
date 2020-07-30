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

          def initialize(step_body)
            super
            @message = step_body['message']
          end

          def transpile
            code = String.new("  ")
            code << function_call('out::message', [@message])
            code << "\n"
          end
        end
      end
    end
  end
end
