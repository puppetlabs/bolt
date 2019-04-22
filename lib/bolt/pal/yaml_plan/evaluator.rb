# frozen_string_literal: true

require 'bolt/pal/yaml_plan'

module Bolt
  class PAL
    class YamlPlan
      class Evaluator
        def initialize(analytics = Bolt::Analytics::NoopClient.new)
          @logger = Logging.logger[self]
          @analytics = analytics
          @evaluator = Puppet::Pops::Parser::EvaluatingParser.new
        end

        STEP_KEYS = %w[task command eval script source plan].freeze

        def dispatch_step(scope, step)
          step = evaluate_code_blocks(scope, step)

          step_type = STEP_KEYS.find { |key| step.key?(key) }

          case step_type
          when 'task'
            task_step(scope, step)
          when 'command'
            command_step(scope, step)
          when 'plan'
            plan_step(scope, step)
          when 'script'
            script_step(scope, step)
          when 'source'
            upload_file_step(scope, step)
          when 'eval'
            eval_step(scope, step)
          end
        end

        def task_step(scope, step)
          task = step['task']
          target = step['target']
          description = step['description']
          params = step['parameters'] || {}

          args = if description
                   [task, target, description, params]
                 else
                   [task, target, params]
                 end

          scope.call_function('run_task', args)
        end

        def plan_step(scope, step)
          plan = step['plan']
          parameters = step['parameters'] || {}

          args = [plan, parameters]

          scope.call_function('run_plan', args)
        end

        def script_step(scope, step)
          script = step['script']
          target = step['target']
          description = step['description']
          arguments = step['arguments'] || []

          options = { 'arguments' => arguments }
          args = if description
                   [script, target, description, options]
                 else
                   [script, target, options]
                 end

          scope.call_function('run_script', args)
        end

        def command_step(scope, step)
          command = step['command']
          target = step['target']
          description = step['description']

          args = [command, target]
          args << description if description
          scope.call_function('run_command', args)
        end

        def upload_file_step(scope, step)
          source = step['source']
          destination = step['destination']
          target = step['target']
          description = step['description']

          args = [source, destination, target]
          args << description if description
          scope.call_function('upload_file', args)
        end

        def eval_step(_scope, step)
          step['eval']
        end

        # This is the method that Puppet calls to evaluate the plan. The name
        # makes more sense for .pp plans.
        def evaluate_block_with_bindings(closure_scope, args_hash, plan)
          plan_result = closure_scope.with_local_scope(args_hash) do |scope|
            plan.steps.each do |step|
              step_result = dispatch_step(scope, step)

              scope.setvar(step['name'], step_result) if step.key?('name')
            end

            evaluate_code_blocks(scope, plan.return)
          end

          throw :return, Puppet::Pops::Evaluator::Return.new(plan_result, nil, nil)
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
