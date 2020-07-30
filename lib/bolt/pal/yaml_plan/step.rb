# frozen_string_literal: true

require 'bolt/util'

module Bolt
  class PAL
    class YamlPlan
      class Step
        attr_reader :name, :type, :body, :targets

        def self.allowed_keys
          Set['name', 'description', 'target', 'targets']
        end

        STEP_KEYS = %w[
          command
          destination
          download
          eval
          message
          plan
          resources
          script
          source
          task
          upload
        ].freeze

        def self.create(step_body, step_number)
          type_keys = (STEP_KEYS & step_body.keys)
          case type_keys.length
          when 0
            raise step_error("No valid action detected", step_body['name'], step_number)
          when 1
            type = type_keys.first
          else
            if [Set['source', 'destination'], Set['upload', 'destination']].include?(type_keys.to_set)
              type = 'upload'
            elsif type_keys.to_set == Set['download', 'destination']
              type = 'download'
            else
              raise step_error("Multiple action keys detected: #{type_keys.inspect}", step_body['name'], step_number)
            end
          end

          step_class = const_get("Bolt::PAL::YamlPlan::Step::#{type.capitalize}")
          step_class.validate(step_body, step_number)
          step_class.new(step_body)
        end

        def initialize(step_body)
          @name = step_body['name']
          @description = step_body['description']
          @targets = step_body['targets'] || step_body['target']
          @body = step_body
        end

        def transpile
          raise NotImplementedError, "Step #{@name} does not supported conversion to Puppet plan language"
        end

        def self.validate(body, step_number)
          validate_step_keys(body, step_number)

          begin
            body.each { |k, v| validate_puppet_code(k, v) }
          rescue Bolt::Error => e
            raise step_error(e.msg, body['name'], step_number)
          end

          unless body.fetch('parameters', {}).is_a?(Hash)
            msg = "Parameters key must be a hash"
            raise step_error(msg, body['name'], step_number)
          end

          if body.key?('name')
            name = body['name']
            unless name.is_a?(String) && name.match?(Bolt::PAL::YamlPlan::VAR_NAME_PATTERN)
              error_message = "Invalid step name: #{name.inspect}"
              raise step_error(error_message, body['name'], step_number)
            end
          end
        end

        def self.validate_step_keys(body, step_number)
          step_type = name.split('::').last.downcase

          # For validated step action, ensure only valid keys
          illegal_keys = body.keys.to_set - allowed_keys
          if illegal_keys.any?
            error_message = "The #{step_type.inspect} step does not support: #{illegal_keys.to_a.inspect} key(s)"
            err = step_error(error_message, body['name'], step_number)
            raise Bolt::Error.new(err, "bolt/invalid-plan")
          end

          # Ensure all required keys are present
          missing_keys = required_keys - body.keys

          # Handle cases where steps with a required 'targets' key are using the deprecated
          # 'target' key instead.
          # TODO: Remove this when 'target' is removed
          if body.include?('target')
            missing_keys -= ['targets']
          end

          # Handle cases where upload step uses deprecated 'source' key instead of 'upload'
          # TODO: Remove when 'source' is removed
          if body.include?('source')
            missing_keys -= ['upload']
          end

          if missing_keys.any?
            error_message = "The #{step_type.inspect} step requires: #{missing_keys.to_a.inspect} key(s)"
            err = step_error(error_message, body['name'], step_number)
            raise Bolt::Error.new(err, "bolt/invalid-plan")
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

        def self.step_error(message, name, step_number)
          identifier = name ? name.inspect : "number #{step_number}"
          error = "Parse error in step #{identifier}: \n #{message}"
          Bolt::Error.new(error, 'bolt/invalid-plan')
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

        def function_call(function, args)
          code_args = args.map { |arg| Bolt::Util.to_code(arg) }
          "#{function}(#{code_args.join(', ')})"
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
