# frozen_string_literal: true

require 'bolt/pal/yaml_plan'

module Bolt
  class PAL
    class YamlPlan
      class Evaluator
        def initialize
          @logger = Logging.logger[self]
          @evaluator = Puppet::Pops::Parser::EvaluatingParser.new
        end

        STEP_KEYS = %w[task command eval].freeze

        def dispatch_step(scope, step)
          step = evaluate_code_blocks(scope, step)

          step_type, *extra_keys = STEP_KEYS.select { |key| step.key?(key) }
          if !step_type || extra_keys.any?
            unsupported_step(scope, step)
          end

          case step_type
          when 'task'
            task_step(scope, step)
          when 'command'
            command_step(scope, step)
          when 'eval'
            eval_step(scope, step)
          else
            # This shouldn't be able to happen since this case statement should
            # match the STEP_KEYS list, but raise an error *just in case*,
            # instead of silently skipping the step.
            unsupported_step(scope, step)
          end
        end

        def task_step(scope, step)
          task = step['task']
          target = step['target']
          description = step['description']
          params = step['parameters'] || {}
          raise "Can't run a task without specifying a target" unless target

          args = if description
                   [task, target, description, params]
                 else
                   [task, target, params]
                 end
          scope.call_function('run_task', args)
        end

        def command_step(scope, step)
          command = step['command']
          target = step['target']
          description = step['description']
          raise "Can't run a command without specifying a target" unless target

          args = [command, target]
          args << description if description
          scope.call_function('run_command', args)
        end

        def eval_step(_scope, step)
          step['eval']
        end

        def unsupported_step(_scope, step)
          raise Bolt::Error.new("Unsupported plan step", "bolt/unsupported-step", step: step)
        end

        # This is the method that Puppet calls to evaluate the plan. The name
        # makes more sense for .pp plans.
        def evaluate_block_with_bindings(closure_scope, args_hash, steps)
          unless steps.is_a?(Array)
            raise Bolt::Error.new("Plan must specify an array of steps", "bolt/invalid-plan")
          end

          closure_scope.with_local_scope(args_hash) do |scope|
            steps.each do |step|
              dispatch_step(scope, step)
            end
          end

          result = nil
          throw :return, Puppet::Pops::Evaluator::Return.new(result, nil, nil)
        end

        # Recursively evaluate any EvaluableString instances in the object.
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
            value.evaluate(scope, @evaluator)
          else
            value
          end
        end

        # Occasionally the Closure will ask us to evaluate what it assumes are
        # AST objects. Because we've sidestepped the AST, they aren't, so just
        # return the values as already evaluated.
        def evaluate(value, _scope)
          value
        end
      end
    end
  end
end
