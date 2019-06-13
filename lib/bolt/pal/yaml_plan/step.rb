# frozen_string_literal: true

require 'bolt/util'

module Bolt
  class PAL
    class YamlPlan
      class Step
        attr_reader :name, :type, :body, :target

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
          },
          'resources' => {
            'allowed_keys' => Set['resources'].merge(COMMON_STEP_KEYS),
            'required_keys' => Set['target']
          }
        }.freeze

        def initialize(step_body, step_number)
          @body = step_body
          @name = @body['name']
          # For error messages
          @step_number = step_number
          validate_step

          @type = STEP_KEYS.keys.find { |key| @body.key?(key) }
          @target = @body['target']
        end

        def transpile(plan_path)
          result = String.new("  ")
          result << "$#{@name} = " if @name

          description = body.fetch('description', nil)
          parameters = body.fetch('parameters', {})
          if @type == 'script' && body.key?('arguments')
            parameters['arguments'] = body['arguments']
          end

          case @type
          when 'command', 'task', 'script', 'plan'
            result << "run_#{@type}(#{Bolt::Util.to_code(body[@type])}"
            result << ", #{Bolt::Util.to_code(@target)}" if @target
            result << ", #{Bolt::Util.to_code(description)}" if description && type != 'plan'
            result << ", #{Bolt::Util.to_code(parameters)}" unless parameters.empty?
            result << ")"
          when 'source'
            result << "upload_file(#{Bolt::Util.to_code(body['source'])}, #{Bolt::Util.to_code(body['destination'])}"
            result << ", #{Bolt::Util.to_code(@target)}" if @target
            result << ", #{Bolt::Util.to_code(description)}" if description
            result << ")"
          when 'eval'
            # We have to do a little extra parsing here, since we only need
            # with() for eval blocks
            code = Bolt::Util.to_code(body['eval'])
            if @name && code.lines.count > 1
              # A little indented niceness
              indented = code.gsub(/\n/, "\n    ").chomp("  ")
              result << "with() || {\n    #{indented}}"
            else
              result << code
            end
          else
            # We should never get here
            raise Bolt::YamlTranspiler::ConvertError.new("Can't convert unsupported step type #{@name}", plan_path)
          end
          result << "\n"
          result
        end

        def validate_step
          validate_step_keys

          begin
            @body.each { |k, v| validate_puppet_code(k, v) }
          rescue Bolt::Error => e
            err = step_err_msg(e.msg)
            raise Bolt::Error.new(err, 'bolt/invalid-plan')
          end

          unless body.fetch('parameters', {}).is_a?(Hash)
            msg = "Parameters key must be a hash"
            raise Bolt::Error.new(step_err_msg(msg), "bolt/invalid-plan")
          end

          if @name
            unless @name.is_a?(String) && @name.match?(Bolt::PAL::YamlPlan::VAR_NAME_PATTERN)
              error_message = "Invalid step name: #{@name.inspect}"
              err = step_err_msg(error_message)
              raise Bolt::Error.new(err, "bolt/invalid-plan")
            end
          end
        end

        def validate_step_keys
          step_keys = @body.keys.to_set
          action = step_keys.intersection(STEP_KEYS.keys.to_set).to_a
          unless action.count == 1
            if action.count > 1
              # Upload step is special in that it is identified by both `source` and `destination`
              unless action.to_set == Set['source', 'destination']
                error_message = "Multiple action keys detected: #{action.inspect}"
                err = step_err_msg(error_message)
                raise Bolt::Error.new(err, "bolt/invalid-plan")
              end
            else
              error_message = "No valid action detected"
              err = step_err_msg(error_message)
              raise Bolt::Error.new(err, "bolt/invalid-plan")
            end
          end

          # For validated step action, ensure only valid keys
          unless STEP_KEYS[action.first]['allowed_keys'].superset?(step_keys)
            illegal_keys = step_keys - STEP_KEYS[action.first]['allowed_keys']
            error_message = "The #{action.first.inspect} step does not support: #{illegal_keys.to_a.inspect} key(s)"
            err = step_err_msg(error_message)
            raise Bolt::Error.new(err, "bolt/invalid-plan")
          end

          # Ensure all required keys are present
          STEP_KEYS[action.first]['required_keys'].each do |k|
            next if step_keys.include?(k)
            missing_keys = STEP_KEYS[action.first]['required_keys'] - step_keys
            error_message = "The #{action.first.inspect} step requires: #{missing_keys.to_a.inspect} key(s)"
            err = step_err_msg(error_message)
            raise Bolt::Error.new(err, "bolt/invalid-plan")
          end
        end

        # Recursively ensure all puppet code can be parsed
        def validate_puppet_code(step_key, value)
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

        def step_err_msg(message)
          if @name
            "Parse error in step number #{@step_number} with name #{@name.inspect}: \n #{message}"
          else
            "Parse error in step number #{@step_number}: \n #{message}"
          end
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
      end
    end
  end
end
