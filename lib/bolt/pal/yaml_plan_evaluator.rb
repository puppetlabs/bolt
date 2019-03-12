# frozen_string_literal: true

require 'yaml'

module Bolt
  class PAL
    class YamlPlanEvaluator
      # For compatibility with the Puppet evaluator
      def evaluate_block_with_bindings(closure_scope, args_hash, plan_body) end

      # As an "evaluator", this object is occasionally called on to evaluate
      # values that are assumed to be bits of AST (as they would if this were a
      # normal Puppet plan). This includes parameter types/values. Since those
      # things are already "evaluated" in this case, we just return them
      # unmodified.
      def evaluate(expr, _scope)
        expr
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
