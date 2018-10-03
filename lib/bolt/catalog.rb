# frozen_string_literal: true

require 'bolt/pal'
require 'bolt/puppetdb'

Bolt::PAL.load_puppet

require 'bolt/catalog/logging'

module Bolt
  class Catalog
    def with_puppet_settings(hiera_config = {})
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

    def generate_ast(code)
      with_puppet_settings do
        Puppet::Pal.in_tmp_environment("bolt_parse") do |pal|
          pal.with_catalog_compiler do |compiler|
            ast = compiler.parse_string(code)
            Puppet::Pops::Serialization::ToDataConverter.convert(ast,
                                                                 rich_data: true,
                                                                 symbol_to_string: true)
          end
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
        Puppet[:rich_data] = true
        Puppet[:node_name_value] = target['name']
        Puppet::Pal.in_tmp_environment('bolt_catalog',
                                       modulepath: request["modulepath"] || [],
                                       facts: target["facts"] || {},
                                       variables: target["variables"] || {}) do |pal|
          Puppet.override(bolt_pdb_client: pdb_client,
                          bolt_inventory: setup_inventory(request['inventory'])) do
            Puppet.lookup(:pal_current_node).trusted_data = target['trusted']
            pal.with_catalog_compiler do |compiler|
              ast = Puppet::Pops::Serialization::FromDataConverter.convert(pal_main)
              compiler.evaluate(ast)
              compiler.compile_additions
              compiler.with_json_encoding(&:encode)
            end
          end
        end
      end
    end
  end
end
