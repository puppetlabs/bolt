# frozen_string_literal: true

require 'yaml'

module Bolt
  class PAL
    class YamlPlanEvaluator
      class PuppetVisitor < Psych::Visitors::NoAliasRuby
        def self.create_visitor
          class_loader = Psych::ClassLoader::Restricted.new([], [])
          scanner = Psych::ScalarScanner.new(class_loader)
          new(scanner, class_loader)
        end

        def visit_Psych_Nodes_Scalar(node) # rubocop:disable Naming/MethodName
          if node.quoted
            case node.style
            when Psych::Nodes::Scalar::SINGLE_QUOTED
              # Single-quoted strings are treated literally
              node.transform
            when Psych::Nodes::Scalar::DOUBLE_QUOTED
              DoubleQuotedString.new(node.value)
            # | style string or > style string
            when Psych::Nodes::Scalar::LITERAL, Psych::Nodes::Scalar::FOLDED
              CodeLiteral.new(node.value)
            # This one shouldn't be possible
            else
              node.transform
            end
          else
            value = node.transform
            if value.is_a?(String)
              BareString.new(value)
            else
              value
            end
          end
        end
      end

      # This class wraps a value parsed from YAML which may be Puppet code.
      # That includes double-quoted strings and string literals, each of which
      # subclasses this parent class in order to implement its own evaluation
      # logic.
      class EvaluableString
        attr_reader :value
        def initialize(value)
          @value = value
        end
      end

      # This class represents a double-quoted YAML string, which is interpreted
      # as though it were a double-quoted Puppet string (with associated
      # variable interpolations)
      class DoubleQuotedString < EvaluableString
        def evaluate(scope, evaluator)
          # "inspect" allows us to get back a double-quoted string literal with
          # special characters escaped. This is based on the assumption that
          # YAML, Ruby and Puppet all support similar escape sequences.
          parse_result = evaluator.parse_string(@value.inspect)

          evaluator.evaluate(scope, parse_result)
        end
      end

      # This represents a literal snippet of Puppet code
      class CodeLiteral < EvaluableString
        def evaluate(scope, evaluator)
          parse_result = evaluator.parse_string(@value)

          evaluator.evaluate(scope, parse_result)
        end
      end

      # This class stores a bare YAML string, which is fuzzily interpreted as
      # either Puppet code or a literal string, depending on whether it starts
      # with a variable reference.
      class BareString < EvaluableString
        def evaluate(scope, evaluator)
          if @value.start_with?('$')
            # Try to parse the string as Puppet code. If it's invalid code,
            # return the original string.
            parse_result = evaluator.parse_string(@value)
            evaluator.evaluate(scope, parse_result)
          else
            @value
          end
        end
      end

      def initialize
        @logger = Logging.logger[self]
        @evaluator = Puppet::Pops::Parser::EvaluatingParser.new
      end

      STEP_KEYS = %w[task command].freeze

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

      def self.parse_plan(yaml_string, source_ref)
        parse_tree = Psych.parse(yaml_string, filename: source_ref)
        PuppetVisitor.create_visitor.accept(parse_tree)
      end

      def self.create(loader, typed_name, source_ref, yaml_string)
        result = parse_plan(yaml_string, source_ref)
        unless result.is_a?(Hash)
          type = result.class.name
          raise ArgumentError, "The data loaded from #{source_ref} does not contain an object - its type is #{type}"
        end

        plan_definition = PlanWrapper.new(typed_name, result).freeze

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

        attr_reader :name, :parameters, :body

        def initialize(name, plan)
          # Top-level plan keys aren't allowed to be Puppet code, so force them
          # all to strings.
          plan = Bolt::Util.walk_keys(plan) { |key| stringify(key) }

          @name = name.freeze

          # Nothing in parameters is allowed to be code, since no variables are defined yet
          params_hash = stringify(plan.fetch('parameters', {}))

          # Munge parameters into an array of Parameter objects, which is what
          # the Puppet API expects
          @parameters = params_hash.map do |param, definition|
            definition ||= {}
            type = Puppet::Pops::Types::TypeParser.singleton.parse(definition['type']) if definition.key?('type')
            Parameter.new(param, definition['default'], type)
          end.freeze

          @body = plan['steps']&.map do |step|
            # Step keys also aren't allowed to be code and neither is the value of "name"
            stringified_step = Bolt::Util.walk_keys(step) { |key| stringify(key) }
            stringified_step['name'] = stringify(stringified_step['name']) if stringified_step.key?('name')
            stringified_step
          end.freeze
        end

        # Turn all "potential" strings in the object into actual strings.
        # Because we interpret bare strings as potential Puppet code, even in
        # places where Puppet code isn't allowed (like some hash keys), we need
        # to be able to force them back into regular strings, as if we had
        # parsed them normally.
        def stringify(value)
          case value
          when Array
            value.map { |element| stringify(element) }
          when Hash
            value.each_with_object({}) do |(k, v), o|
              o[stringify(k)] = stringify(v)
            end
          when EvaluableString
            value.value
          else
            value
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
