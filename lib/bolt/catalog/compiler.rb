# frozen_string_literal: true

# This class exists to override evaluate_main and let us inject
# AST instead of looking for the main manifest. A better option may be to set up the
# node environment so our AST is in the '' hostclass instead of doing it here.
module Puppet
  module Parser
    class BoltCompiler < Puppet::Parser::Compiler
      def internal_evaluator
        @internal_evaluator ||= Puppet::Pops::Parser::EvaluatingParser.new
      end

      def dump_ast(ast)
        Puppet::Pops::Serialization::ToDataConverter.convert(ast, rich_data: true, symbol_to_string: true)
      end

      def load_ast(ast_data)
        Puppet::Pops::Serialization::FromDataConverter.convert(ast_data)
      end

      def parse_string(string, file = '')
        internal_evaluator.parse_string(string, file)
      end

      def evaluate_main
        main = Puppet.lookup(:pal_main)
        ast = if main.is_a?(String)
                parse_string(main)
              else
                load_ast(main)
              end

        bridge = Puppet::Parser::AST::PopsBridge::Program.new(ast)

        # This is more or less copypaste from the super but we don't use the
        # original host_class.
        krt = environment.known_resource_types
        @main = krt.add(Puppet::Resource::Type.new(:hostclass, '', code: bridge))
        @topscope.source = @main
        @main_resource = Puppet::Parser::Resource.new('class', :main, scope: @topscope, source: @main)
        @topscope.resource = @main_resource
        add_resource(@topscope, @main_resource)

        @main_resource.evaluate
      end
    end
  end
end
