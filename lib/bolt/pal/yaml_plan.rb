# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      PLAN_KEYS = Set['parameters', 'steps', 'return', 'version']
      PARAMETER_KEYS = Set['type', 'default']
      COMMON_STEP_KEYS = %w[name description target].freeze
      STEP_KEYS = {
        'command' => {
          'allowed_keys' => Set['command'].merge(COMMON_STEP_KEYS),
          'required_keys' => Set['target']
        },
        'script' => {
          'allowed_keys' => Set['script', 'parameters', 'arguments'].merge(COMMON_STEP_KEYS),
          'required_keys' => Set['target']
        },
        'task' => {
          'allowed_keys' => Set['task', 'parameters'].merge(COMMON_STEP_KEYS),
          'required_keys' => Set['target']
        },
        'plan' => {
          'allowed_keys' => Set['plan', 'parameters'].merge(COMMON_STEP_KEYS),
          'required_keys' => Set.new
        },
        'source' => {
          'allowed_keys' => Set['source', 'destination'].merge(COMMON_STEP_KEYS),
          'required_keys' => Set['target', 'source', 'destination']
        },
        'destination' => {
          'allowed_keys' => Set['source', 'destination'].merge(COMMON_STEP_KEYS),
          'required_keys' => Set['target', 'source', 'destination']
        },
        'eval' => {
          'allowed_keys' => Set['eval', 'name', 'description'],
          'required_keys' => Set.new
        }
      }.freeze

      Parameter = Struct.new(:name, :value, :type_expr) do
        def captures_rest
          false
        end
      end

      attr_reader :name, :parameters, :steps, :return

      def initialize(name, plan)
        # Top-level plan keys aren't allowed to be Puppet code, so force them
        # all to strings.
        plan = Bolt::Util.walk_keys(plan) { |key| stringify(key) }
        @name = name.freeze

        # Nothing in parameters is allowed to be code, since no variables are defined yet
        params_hash = stringify(plan.fetch('parameters', {}))

        # Ensure params is a hash
        unless params_hash.is_a?(Hash)
          raise Bolt::Error.new("Plan parameters must be a Hash", "bolt/invalid-plan")
        end

        # Validate top level plan keys
        top_level_keys = plan.keys.to_set
        unless PLAN_KEYS.superset?(top_level_keys)
          invalid_keys = top_level_keys - PLAN_KEYS
          raise Bolt::Error.new("Plan contains illegal key(s) #{invalid_keys.to_a.inspect}",
                                "bolt/invalid-plan")
        end

        # Munge parameters into an array of Parameter objects, which is what
        # the Puppet API expects
        @parameters = params_hash.map do |param, definition|
          definition ||= {}
          definition_keys = definition.keys.to_set
          unless PARAMETER_KEYS.superset?(definition_keys)
            invalid_keys = definition_keys - PARAMETER_KEYS
            raise Bolt::Error.new("Plan parameter #{param.inspect} contains illegal key(s)" \
                                  " #{invalid_keys.to_a.inspect}",
                                  "bolt/invalid-plan")
          end
          type = Puppet::Pops::Types::TypeParser.singleton.parse(definition['type']) if definition.key?('type')
          Parameter.new(param, definition['default'], type)
        end.freeze

        @steps = plan['steps']&.map do |step|
          # Step keys also aren't allowed to be code and neither is the value of "name"
          stringified_step = Bolt::Util.walk_keys(step) { |key| stringify(key) }
          stringified_step['name'] = stringify(stringified_step['name']) if stringified_step.key?('name')
          stringified_step
        end.freeze

        @return = plan['return']

        validate
      end

      VAR_NAME_PATTERN = /\A[a-z_][a-z0-9_]*\z/.freeze

      def validate
        unless @steps.is_a?(Array)
          raise Bolt::Error.new("Plan must specify an array of steps", "bolt/invalid-plan")
        end

        used_names = Set.new
        step_number = 1

        # Parameters come in a hash, so they must be unique
        @parameters.each do |param|
          unless param.name.is_a?(String) && param.name.match?(VAR_NAME_PATTERN)
            raise Bolt::Error.new("Invalid parameter name #{param.name.inspect}", "bolt/invalid-plan")
          end

          used_names << param.name
        end

        @steps.each do |step|
          validate_step_keys(step, step_number)

          begin
            step.each { |k, v| validate_puppet_code(k, v) }
          rescue Bolt::Error => e
            raise Bolt::Error.new(step_err_msg(step_number, step['name'], e.msg), 'bolt/invalid-plan')
          end

          if step.key?('name')
            unless step['name'].is_a?(String) && step['name'].match?(VAR_NAME_PATTERN)
              error_message = "Invalid step name: #{step['name'].inspect}"
              raise Bolt::Error.new(step_err_msg(step_number, step['name'], error_message), "bolt/invalid-plan")
            end

            if used_names.include?(step['name'])
              error_message = "Duplicate step name or parameter detected: #{step['name'].inspect}"
              raise Bolt::Error.new(step_err_msg(step_number, step['name'], error_message), "bolt/invalid-plan")
            end

            used_names << step['name']
          end
          step_number += 1
        end
      end

      def body
        self
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

      def step_err_msg(step_number, step_name, message)
        if step_name
          "Parse error in step number #{step_number} with name #{step_name.inspect}: \n #{message}"
        else
          "Parse error in step number #{step_number}: \n #{message}"
        end
      end

      def validate_step_keys(step, step_number)
        step_keys = step.keys.to_set
        action = step_keys.intersection(STEP_KEYS.keys.to_set).to_a
        unless action.count == 1
          if action.count > 1
            # Upload step is special in that it is identified by both `source` and `destination`
            unless action.to_set == Set['source', 'destination']
              error_message = "Multiple action keys detected: #{action.inspect}"
              raise Bolt::Error.new(step_err_msg(step_number, step['name'], error_message), "bolt/invalid-plan")
            end
          else
            error_message = "No valid action detected"
            raise Bolt::Error.new(step_err_msg(step_number, step['name'], error_message), "bolt/invalid-plan")
          end
        end

        # For validated step action, ensure only valid keys
        unless STEP_KEYS[action.first]['allowed_keys'].superset?(step_keys)
          illegal_keys = step_keys - STEP_KEYS[action.first]['allowed_keys']
          error_message = "The #{action.first.inspect} step does not support: #{illegal_keys.to_a.inspect} key(s)"
          raise Bolt::Error.new(step_err_msg(step_number, step['name'], error_message), "bolt/invalid-plan")
        end

        # Ensure all required keys are present
        STEP_KEYS[action.first]['required_keys'].each do |k|
          next if step_keys.include?(k)
          missing_keys = STEP_KEYS[action.first]['required_keys'] - step_keys
          error_message = "The #{action.first.inspect} step requires: #{missing_keys.to_a.inspect} key(s)"
          raise Bolt::Error.new(step_err_msg(step_number, step['name'], error_message), "bolt/invalid-plan")
        end
      end

      # Recursively ensure all puppet code can be parsed
      def validate_puppet_code(step_key, value)
        case value
        when Array
          value.map { |element| validate_puppet_code(step_key, element) }
        when Hash
          value.each_with_object({}) do |(k, v), o|
            key = k.is_a?(EvaluableString) ? k.value : k
            o[key] = validate_puppet_code(key, v)
          end
        # CodeLiterals can be parsed directly
        when CodeLiteral
          parse_code_string(value.value)
        # BareString is parsed directly if it starts with '$'
        when BareString
          if value.value.start_with?('$')
            parse_code_string(value.value)
          else
            parse_code_string(value.value, true)
          end
        when EvaluableString
          # Must quote parsed strings to evaluate them
          parse_code_string(value.value, true)
        end
      rescue Puppet::Error => e
        raise Bolt::Error.new("Error parsing #{step_key.inspect}: #{e.basic_message}", "bolt/invalid-plan")
      end

      # Parses the an evaluable string, optionally quote it before parsing
      def parse_code_string(code, quote = false)
        if quote
          quoted = Puppet::Pops::Parser::EvaluatingParser.quote(code)
          Puppet::Pops::Parser::EvaluatingParser.new.parse_string(quoted)
        else
          Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code)
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
