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

        def dispatch_step(scope, step)
          step_body = evaluate_code_blocks(scope, step.body)

          # Dispatch based on the step class name
          step_type = step.class.name.split('::').last.downcase
          method = "#{step_type}_step"

          send(method, scope, step_body)
        end

        def task_step(scope, step)
          task = step['task']
          targets = step['targets'] || step['target']
          description = step['description']
          params = step['parameters'] || {}

          args = if description
                   [task, targets, description, params]
                 else
                   [task, targets, params]
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
          targets = step['targets'] || step['target']
          description = step['description']
          arguments = step['arguments'] || []

          options = { 'arguments' => arguments }
          args = if description
                   [script, targets, description, options]
                 else
                   [script, targets, options]
                 end

          scope.call_function('run_script', args)
        end

        def command_step(scope, step)
          command = step['command']
          targets = step['targets'] || step['target']
          description = step['description']

          args = [command, targets]
          args << description if description
          scope.call_function('run_command', args)
        end

        def upload_step(scope, step)
          source = step['source']
          destination = step['destination']
          targets = step['targets'] || step['target']
          description = step['description']

          args = [source, destination, targets]
          args << description if description
          scope.call_function('upload_file', args)
        end

        def eval_step(_scope, step)
          step['eval']
        end

        def resources_step(scope, step)
          targets = step['targets'] || step['target']

          # TODO: Only call apply_prep when needed
          scope.call_function('apply_prep', targets)
          manifest = generate_manifest(step['resources'])

          apply_manifest(scope, targets, manifest)
        end

        def generate_manifest(resources)
          # inspect returns the Ruby representation of the resource hashes,
          # which happens to be the same as the Puppet representation
          puppet_resources = resources.inspect

          # Because the :tasks setting globally controls which mode the parser
          # is in, we need to make this snippet of non-tasks manifest code
          # parseable in tasks mode. The way to do that is by putting it in an
          # apply statement and taking the body.
          <<~MANIFEST
          apply('placeholder') {
            $resources = #{puppet_resources}
            $resources.each |$res| {
              Resource[$res['type']] { $res['title']:
                * => $res['parameters'],
              }
            }

            # Add relationships if there is more than one resource
            if $resources.length > 1 {
              ($resources.length - 1).each |$index| {
                $lhs = $resources[$index]
                $rhs = $resources[$index+1]
                $lhs_resource = Resource[$lhs['type'] , $lhs['title']]
                $rhs_resource = Resource[$rhs['type'] , $rhs['title']]
                $lhs_resource -> $rhs_resource
              }
            }
          }
          MANIFEST
        end

        def apply_manifest(scope, targets, manifest)
          ast = @evaluator.parse_string(manifest)
          apply_block = ast.body.body
          applicator = Puppet.lookup(:apply_executor)
          applicator.apply([targets], apply_block, scope)
        end

        # This is the method that Puppet calls to evaluate the plan. The name
        # makes more sense for .pp plans.
        def evaluate_block_with_bindings(closure_scope, args_hash, plan)
          if plan.steps.any? { |step| step.body.key?('target') }
            msg = "The 'target' parameter for YAML plan steps is deprecated and will be removed "\
                  "in a future version of Bolt. Use the 'targets' parameter instead."
            Bolt::Logger.deprecation_warning("Using 'target' parameter for YAML plan steps, not 'targets'", msg)
          end

          plan_result = closure_scope.with_local_scope(args_hash) do |scope|
            plan.steps.each do |step|
              step_result = dispatch_step(scope, step)

              scope.setvar(step.name, step_result) if step.name
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
