# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Eval < Step
          def self.required_keys
            Set['eval']
          end

          # Evaluates the step
          #
          def evaluate(scope, evaluator)
            evaluated = evaluator.evaluate_code_blocks(scope, body)
            evaluated['eval']
          end

          # Transpiles the step into the plan language
          #
          def transpile
            code = String.new("  ")
            code << "$#{body['name']} = " if body['name']

            code_body = Bolt::Util.to_code(body['eval']) || 'undef'

            # If we're trying to assign the result of a multi-line eval to a name
            # variable, we need to wrap it in `with()`.
            if body['name'] && code_body.lines.count > 1
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
