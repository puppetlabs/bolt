# frozen_string_literal: true

require 'bolt/pal/yaml_plan'

module Bolt
  class PAL
    class YamlPlan
      class Evaluator
        def initialize(analytics = Bolt::Analytics::NoopClient.new)
          @logger = Bolt::Logger.logger(self)
          @analytics = analytics
          @evaluator = Puppet::Pops::Parser::EvaluatingParser.new
        end

        # This is the method that Puppet calls to evaluate the plan. The name
        # makes more sense for .pp plans.
        #
        def evaluate_block_with_bindings(closure_scope, args_hash, plan)
          plan_result = closure_scope.with_local_scope(args_hash) do |scope|
            plan.steps.each do |step|
              step_result = step.evaluate(scope, self)

              scope.setvar(step.body['name'], step_result) if step.body['name']
            end

            evaluate_code_blocks(scope, plan.return)
          end

          throw :return, Puppet::Pops::Evaluator::Return.new(plan_result, nil, nil)
        end

        # Recursively evaluate any EvaluableString instances in the object.
        #
        def evaluate_code_blocks(scope, value)
          # XXX We should establish a local scope here probably
          case value
          when Array
            value.map { |element| evaluate_code_blocks(scope, element) }
          when Hash
            value.each_with_object({}) do |(k, v), o|
              key = k.is_a?(EvaluableString) ? k.value : k
              o[key] = evaluate_code_blocks(scope, v)
            end
          when EvaluableString
            begin
              value.evaluate(scope, @evaluator)
            rescue StandardError => e
              raise format_evaluate_error(e, value)
            end
          else
            value
          end
        end

        # Occasionally the Closure will ask us to evaluate what it assumes are
        # AST objects. Because we've sidestepped the AST, they aren't, so just
        # return the values as already evaluated.
        #
        def evaluate(value, _scope)
          value
        end

        def format_evaluate_error(error, value)
          # The Puppet::PreformattedError includes the line number of the
          # evaluable string that caused the error, while the value includes the
          # line number of the YAML plan that the string began on. To get the
          # actual line number of the error, add these two numbers together.
          line = error.line + value.line

          # If the evaluable string is not a scalar literal, correct for it
          # being on the same line as the step key.
          line -= 1 if value.is_a?(BareString)

          Bolt::PlanFailure.new(
            error.basic_message,
            'bolt/evaluation-error',
            { file: value.file, line: line }
          )
        end
      end
    end
  end
end
