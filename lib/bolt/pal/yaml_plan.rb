# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
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

          scope.with_local_scope({}) do
            evaluator.evaluate(scope, parse_result)
          end
        end
      end

      # This represents a literal snippet of Puppet code
      class CodeLiteral < EvaluableString
        def evaluate(scope, evaluator)
          parse_result = evaluator.parse_string(@value)

          scope.with_local_scope({}) do
            evaluator.evaluate(scope, parse_result)
          end
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
            scope.with_local_scope({}) do
              evaluator.evaluate(scope, parse_result)
            end
          else
            @value
          end
        end
      end
    end
  end
end
