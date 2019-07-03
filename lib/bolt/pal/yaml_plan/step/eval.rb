# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Eval < Step
          def self.allowed_keys
            super + Set['eval']
          end

          def self.required_keys
            Set.new
          end

          def initialize(step_body)
            super
            @eval = step_body['eval']
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            code_body = Bolt::Util.to_code(@eval)

            # If we're trying to assign the result of a multi-line eval to a name
            # variable, we need to wrap it in `with()`.
            if @name && code_body.lines.count > 1
              indented = code_body.gsub(/\n/, "\n    ").chomp("  ")
              code << "with() || {\n    #{indented}}"
            else
              code << code_body
            end

            code << "\n"
          end
        end
      end
    end
  end
end
