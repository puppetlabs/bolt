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

          def deserialize(node)
            if node.quoted
              case node.style
              when Psych::Nodes::Scalar::SINGLE_QUOTED
                # Single-quoted strings are treated literally
                # @ss is a ScalarScanner, from the base ToRuby visitor class
                node.value
              when Psych::Nodes::Scalar::DOUBLE_QUOTED
                DoubleQuotedString.new(node.value)
              # | style string or > style string
              when Psych::Nodes::Scalar::LITERAL, Psych::Nodes::Scalar::FOLDED
                CodeLiteral.new(node.value)
              # This one shouldn't be possible
              else
                @ss.tokenize(node.value)
              end
            else
              value = @ss.tokenize(node.value)
              if value.is_a?(String)
                BareString.new(value)
              else
                value
              end
            end
          end
        end

        def self.parse_plan(yaml_string, source_ref)
          # This passes the filename as the second arg for compatibility with Psych used with ruby < 2.6
          # This can be removed when we remove support for ruby 2.5
          parse_tree = if Psych.method(:parse).parameters.include?('legacy_filename')
                         Psych.parse(yaml_string, filename: source_ref)
                       else
                         Psych.parse(yaml_string, source_ref)
                       end
          PuppetVisitor.create_visitor.accept(parse_tree)
        end

        def self.create(loader, typed_name, source_ref, yaml_string)
          result = parse_plan(yaml_string, source_ref)
          unless result.is_a?(Hash)
            type = result.class.name
            raise ArgumentError, "The data loaded from #{source_ref} does not contain an object - its type is #{type}"
          end

          begin
            plan_definition = YamlPlan.new(typed_name, result).freeze
          rescue Bolt::Error => e
            raise Puppet::ParseError.new(e.message, source_ref)
          end

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
