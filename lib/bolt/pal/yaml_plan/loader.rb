# frozen_string_literal: true

require 'bolt/pal/yaml_plan'
require 'bolt/pal/yaml_plan/evaluator'
require 'psych'

module Bolt
  class PAL
    class YamlPlan
      class Loader
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

          plan_definition = YamlPlan.new(typed_name, result).freeze

          created = create_function_class(plan_definition)
          closure_scope = nil

          created.new(closure_scope, loader.private_loader)
        end

        def self.create_function_class(plan_definition)
          Puppet::Functions.create_function(plan_definition.name, Puppet::Functions::PuppetFunction) do
            closure = Puppet::Pops::Evaluator::Closure::Named.new(plan_definition.name,
                                                                  YamlPlan::Evaluator.new,
                                                                  plan_definition)
            init_dispatch(closure)
          end
        end
      end
    end
  end
end
