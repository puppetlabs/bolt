# frozen_string_literal: true

require 'bolt/pal'
require 'bolt/puppetdb'

Bolt::PAL.load_puppet

require 'bolt/catalog/compiler'
require 'bolt/catalog/loaders'
require 'bolt/catalog/logging'

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

        # Use a special logdest that serializes all log messages and their level to stderr.
        Puppet::Util::Log.newdestination(:stderr)
        Puppet.settings[:log_level] = 'debug'
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
      # Add boltlib to system loaders so modules can use its functions without an
      # explicit dependency.
      node.environment.loaders = Bolt::Catalog::BoltLoaders.new(node.environment)

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

    def setup_inventory(inventory)
      config = Bolt::Config.default
      config.overwrite_transport_data(inventory['config']['transport'],
                                      Bolt::Util.symbolize_top_level_keys(inventory['config']['transports']))

      Bolt::Inventory.new(inventory['data'],
                          config,
                          Bolt::Util.symbolize_top_level_keys(inventory['target_hash']))
    end

    def compile_catalog(request)
      pal_main = request['code_ast'] || request['code_string']
      target = request['target']

      pdb_client = Bolt::PuppetDB::Client.new(Bolt::PuppetDB::Config.new(request['pdb_config']))

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

          # Ensure files that custom facts and types/providers depend on can be loaded
          node.environment.each_plugin_directory do |dir|
            $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
          end

          setup_node(node, target["trusted"])

          Puppet.override(pal_main: pal_main,
                          bolt_pdb_client: pdb_client,
                          bolt_inventory:
                          setup_inventory(request['inventory'])) do
            compile_node(node)
          end
        end
      end
    end
  end
end
