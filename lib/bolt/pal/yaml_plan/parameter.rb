# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Parameter
        attr_reader :name, :value, :type_expr, :description

        PARAMETER_KEYS = Set['type', 'default', 'description']

        def initialize(param, definition)
          definition ||= {}
          validate_param(param, definition)

          @name = param
          @value = definition['default']
          @type_expr = Puppet::Pops::Types::TypeParser.singleton.parse(definition['type']) if definition['type']
          @description = definition['description']
        end

        def validate_param(param, definition)
          unless param.is_a?(String) && param.match?(Bolt::PAL::YamlPlan::VAR_NAME_PATTERN)
            raise Bolt::Error.new("Invalid parameter name #{param.inspect}", "bolt/invalid-plan")
          end

          definition_keys = definition.keys.to_set
          unless PARAMETER_KEYS.superset?(definition_keys)
            invalid_keys = definition_keys - PARAMETER_KEYS
            raise Bolt::Error.new("Plan parameter #{param.inspect} contains illegal key(s)" \
                                  " #{invalid_keys.to_a.inspect}",
                                  "bolt/invalid-plan")
          end
        end

        def captures_rest
          false
        end

        def transpile
          result = String.new
          result << "\n\s\s"

          # Param type
          if @type_expr.respond_to?(:type_string)
            result << @type_expr.type_string + " "
          elsif !@type_expr.nil?
            result << @type_expr.to_s + " "
          end

          # Param name
          result << "$#{@name}"

          # Param default
          if @value
            default = @type_expr.to_s =~ /String/ ? "'#{@value}'" : @value
            result << " = #{default}"
          end
          result
        end
      end
    end
  end
end
