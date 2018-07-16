# frozen_string_literal: true

require 'bolt/pal'
require 'bolt/puppetdb'
require 'bolt/util/on_access'

Bolt::PAL.load_puppet

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

module Bolt
  class Catalog
    def with_puppet_settings(hiera_config)
      Dir.mktmpdir('bolt') do |dir|
        cli = []
        Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
          cli << "--#{setting}" << dir
        end
        Puppet.settings.send(:clear_everything_for_tests)
        Puppet.initialize_settings(cli)
        Puppet.settings[:hiera_config] = hiera_config
        # self.class.configure_logging
        yield
      end
    end

    def setup_node(node, trusted)
      facts = Puppet.lookup(:pal_facts)
      node_facts = Puppet::Node::Facts.new(Puppet[:node_name_value], facts)
      node.fact_merge(node_facts)

      node.parameters = node.parameters.merge(Puppet.lookup(:pal_variables))
      node.trusted_data = trusted
    end

    def compile_node(node)
      compiler = Puppet::Parser::BoltCompiler.new(node)
      compiler.compile(&:to_resource)
    end

    def generate_ast(code)
      with_puppet_settings do
        Puppet::Pal.in_tmp_environment("bolt_parse") do |_pal|
          node = Puppet.lookup(:pal_current_node)
          compiler = Puppet::Parser::BoltCompiler.new(node)
          compiler.dump_ast(compiler.parse_string(code))
        end
      end
    end

    def compile_catalog(request)
      pal_main = request['code_ast'] || request['code_string']
      target = request['target']

      pdb_client = Bolt::Util::OnAccess.new do
        pdb_config = Bolt::PuppetDB::Config.new(nil, request['pdb_config'])
        Bolt::PuppetDB::Client.from_config(pdb_config)
      end

      with_puppet_settings(request['hiera_config']) do
        Puppet[:code] = ''
        Puppet[:node_name_value] = target['name']
        Puppet::Pal.in_tmp_environment(
          'bolt_catalog',
          modulepath: request["modulepath"] || [],
          facts: target["facts"] || {},
          variables: target["variables"] || {}
        ) do |_pal|
          node = Puppet.lookup(:pal_current_node)
          setup_node(node, target["trusted"])

          Puppet.override(pal_main: pal_main, bolt_pdb_client: pdb_client) do
            compile_node(node)
          end
        end
      end
    end
  end
end
