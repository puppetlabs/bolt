# frozen_string_literal: true

require 'bolt/util'

module Bolt
  class PAL
    class YamlPlan
      class Step
        attr_reader :body

        STEP_KEYS = %w[
          command
          download
          eval
          message
          plan
          resources
          script
          task
          upload
        ].freeze

        class StepError < Bolt::Error
          def initialize(message, name, step_number)
            identifier = name ? name.inspect : "number #{step_number}"
            error      = "Parse error in step #{identifier}: \n #{message}"

            super(error, 'bolt/invalid-plan')
          end
        end

        # Keys that are allowed for the step
        #
        def self.allowed_keys
          required_keys + option_keys + Set['name', 'description', 'targets']
        end

        # Keys that translate to metaparameters for the plan step's function call
        #
        def self.option_keys
          Set.new
        end

        # Keys that are required for the step
        #
        def self.required_keys
          Set.new
        end

        def self.create(step_body, step_number)
          type_keys = (STEP_KEYS & step_body.keys)
          case type_keys.length
          when 0
            raise StepError.new("No valid action detected", step_body['name'], step_number)
          when 1
            type = type_keys.first
          else
            raise StepError.new("Multiple action keys detected: #{type_keys.inspect}", step_body['name'], step_number)
          end

          step_class = const_get("Bolt::PAL::YamlPlan::Step::#{type.capitalize}")
          step_class.validate(step_body, step_number)
          step_class.new(step_body)
        end

        def initialize(body)
          @body = body
        end

        # Transpiles the step into the plan language
        #
        def transpile
          code = String.new("  ")
          code << "$#{body['name']} = " if body['name']
          code << function_call(function, format_args(body))
          code << "\n"
        end

        # Evaluates the step
        #
        def evaluate(scope, evaluator)
          evaluated = evaluator.evaluate_code_blocks(scope, body)
          scope.call_function(function, format_args(evaluated))
        end

        # Formats a list of args from the provided body
        #
        private def format_args(_body)
          raise NotImplementedError, "Step class #{self.class} does not implement #args"
        end

        # Returns the step's corresponding Puppet language function call
        #
        private def function_call(function, args)
          code_args = args.map { |arg| Bolt::Util.to_code(arg) }
          "#{function}(#{code_args.join(', ')})"
        end

        # The function that corresponds to the step
        #
        private def function
          raise NotImplementedError, "Step class #{self.class} does not implement #function"
        end

        # Returns a hash of options formatted for function calls
        #
        private def format_options(body)
          body.slice(*self.class.option_keys).transform_keys { |key| "_#{key}" }
        end

        def self.validate(body, step_number)
          validate_step_keys(body, step_number)

          begin
            body.each { |k, v| validate_puppet_code(k, v) }
          rescue Bolt::Error => e
            raise StepError.new(e.msg, body['name'], step_number)
          end

          if body.key?('parameters')
            unless body['parameters'].is_a?(Hash)
              raise StepError.new("Parameters key must be a hash", body['name'], step_number)
            end

            metaparams = option_keys.map { |key| "_#{key}" }

            if (dups = body['parameters'].keys & metaparams).any?
              raise StepError.new(
                "Cannot specify metaparameters when using top-level keys with same name: #{dups.join(', ')}",
                body['name'],
                step_number
              )
            end
          end

          unless body.fetch('parameters', {}).is_a?(Hash)
            msg = "Parameters key must be a hash"
            raise StepError.new(msg, body['name'], step_number)
          end

          if body.key?('name')
            name = body['name']
            unless name.is_a?(String) && name.match?(Bolt::PAL::YamlPlan::VAR_NAME_PATTERN)
              error_message = "Invalid step name: #{name.inspect}"
              raise StepError.new(error_message, body['name'], step_number)
            end
          end
        end

        def self.validate_step_keys(body, step_number)
          step_type = name.split('::').last.downcase

          # For validated step action, ensure only valid keys
          illegal_keys = body.keys.to_set - allowed_keys
          if illegal_keys.any?
            error_message = "The #{step_type.inspect} step does not support: #{illegal_keys.to_a.inspect} key(s)"
            raise StepError.new(error_message, body['name'], step_number)
          end

          # Ensure all required keys are present
          missing_keys = required_keys - body.keys

          if missing_keys.any?
            error_message = "The #{step_type.inspect} step requires: #{missing_keys.to_a.inspect} key(s)"
            raise StepError.new(error_message, body['name'], step_number)
          end
        end

        # Recursively ensure all puppet code can be parsed
        def self.validate_puppet_code(step_key, value)
          case value
          when Array
            value.map { |element| validate_puppet_code(step_key, element) }
          when Hash
            value.each_with_object({}) do |(k, v), o|
              key = k.is_a?(Bolt::PAL::YamlPlan::EvaluableString) ? k.value : k
              o[key] = validate_puppet_code(key, v)
            end
            # CodeLiterals can be parsed directly
          when Bolt::PAL::YamlPlan::CodeLiteral
            parse_code_string(value.value)
            # BareString is parsed directly if it starts with '$'
          when Bolt::PAL::YamlPlan::BareString
            if value.value.start_with?('$')
              parse_code_string(value.value)
            else
              parse_code_string(value.value, true)
            end
          when Bolt::PAL::YamlPlan::EvaluableString
            # Must quote parsed strings to evaluate them
            parse_code_string(value.value, true)
          end
        rescue Puppet::Error => e
          raise Bolt::Error.new("Error parsing #{step_key.inspect}: #{e.basic_message}", "bolt/invalid-plan")
        end

        # Parses the an evaluable string, optionally quote it before parsing
        def self.parse_code_string(code, quote = false)
          if quote
            quoted = Puppet::Pops::Parser::EvaluatingParser.quote(code)
            Puppet::Pops::Parser::EvaluatingParser.new.parse_string(quoted)
          else
            Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code)
          end
        end
      end
    end
  end
end

require 'bolt/pal/yaml_plan/step/command'
require 'bolt/pal/yaml_plan/step/eval'
require 'bolt/pal/yaml_plan/step/plan'
require 'bolt/pal/yaml_plan/step/resources'
require 'bolt/pal/yaml_plan/step/script'
require 'bolt/pal/yaml_plan/step/task'
require 'bolt/pal/yaml_plan/step/upload'
require 'bolt/pal/yaml_plan/step/download'
require 'bolt/pal/yaml_plan/step/message'
