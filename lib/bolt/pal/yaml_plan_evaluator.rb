# frozen_string_literal: true

require 'yaml'

module Bolt
  class PAL
    class YamlPlanEvaluator
      def initialize
        @logger = Logging.logger[self]
        @evaluator = Puppet::Pops::Parser::EvaluatingParser.new
      end

      STEP_KEYS = %w[task command].freeze

      def dispatch_step(scope, step)
        step_type, *extra_keys = STEP_KEYS.select { |key| step.key?(key) }
        if !step_type || extra_keys.any?
          unsupported_step(scope, step)
        end

        case step_type
        when 'task'
          task_step(scope, step)
        when 'command'
          command_step(scope, step)
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

        target = interpolate_variables(scope, target)
        params = Bolt::Util.map_vals(params) { |param| interpolate_variables(scope, param) }

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

        target = interpolate_variables(scope, target)

        args = [command, target]
        args << description if description
        scope.call_function('run_command', args)
      end

      def unsupported_step(_scope, step)
        raise Bolt::Error.new("Unsupported plan step", "bolt/unsupported-step", step: step)
      end

      def evaluate_block_with_bindings(closure_scope, args_hash, plan_body)
        unless plan_body['steps'].is_a?(Array)
          raise Bolt::Error.new("Plan must specify an array of steps", "bolt/invalid-plan")
        end

        closure_scope.with_local_scope(args_hash) do |scope|
          plan_body['steps'].each do |step|
            dispatch_step(scope, step)
          end
        end

        result = nil
        throw :return, Puppet::Pops::Evaluator::Return.new(result, nil, nil)
      end

      # Evaluate strings which contain *exactly* a variable reference.
      # Otherwise return the value unmodified.
      def interpolate_variables(scope, value)
        if value.is_a?(String)
          # Try to parse the string as Puppet code. If it's invalid code,
          # return the original string.
          begin
            parse_result = @evaluator.parse_string(value)
          rescue Puppet::ParseError
            return value
          else
            if parse_result.body.is_a?(Puppet::Pops::Model::VariableExpression)
              # If we just evaluate the string, errors will reference "line 1", which is wrong
              return scope.lookupvar(parse_result.body.expr.value)
            end
          end
        end

        value
      end

      # Occasionally the Closure will ask us to evaluate what it assumes are
      # AST objects. Because we've sidestepped the AST, they aren't, so just
      # return the values as already evaluated.
      def evaluate(value, _scope)
        value
      end

      def self.create(loader, typed_name, source_ref, yaml_string)
        body = YAML.safe_load(yaml_string, [Symbol], [], true, source_ref)
        unless body.is_a?(Hash)
          type = body.class.name
          raise ArgumentError, "The data loaded from #{source_ref} does not contain an object - its type is #{type}"
        end

        plan_definition = PlanWrapper.new(typed_name, body)

        created = create_function_class(plan_definition)
        closure_scope = nil

        created.new(closure_scope, loader.private_loader)
      end

      def self.create_function_class(plan_definition)
        Puppet::Functions.create_function(plan_definition.name, Puppet::Functions::PuppetFunction) do
          closure = Puppet::Pops::Evaluator::Closure::Named.new(plan_definition.name,
                                                                YamlPlanEvaluator.new,
                                                                plan_definition)
          init_dispatch(closure)
        end
      end

      class PlanWrapper
        Parameter = Struct.new(:name, :value, :type_expr) do
          def captures_rest
            false
          end
        end

        attr_reader :name, :body

        def initialize(name, body)
          @name = name
          @body = body
        end

        def parameters
          @parameters ||= @body.fetch('parameters', {}).map do |name, definition|
            definition ||= {}
            type = Puppet::Pops::Types::TypeParser.singleton.parse(definition['type']) if definition.key?('type')
            Parameter.new(name, definition['default'], type)
          end
        end

        def return_type
          Puppet::Pops::Types::TypeParser.singleton.parse('Boltlib::PlanResult')
        end
        # XXX maybe something about location
      end
    end
  end
end
