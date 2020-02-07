# frozen_string_literal: true

require 'bolt/apply_target'
require 'bolt/config'
require 'bolt/error'
require 'bolt/inventory'
require 'bolt/apply_inventory'
require 'bolt/pal'
require 'bolt/puppetdb'
require 'bolt/util'

Bolt::PAL.load_puppet

require 'bolt/catalog/logging'

module Bolt
  class Catalog
    def initialize(log_level = 'debug')
      @log_level = log_level
    end

    def with_puppet_settings(hiera_config = {})
      Dir.mktmpdir('bolt') do |dir|
        cli = []
        Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
          cli << "--#{setting}" << dir
        end
        Puppet.settings.send(:clear_everything_for_tests)
        # Override module locations, Bolt includes vendored modules in its internal modulepath.
        Puppet.settings.override_default(:basemodulepath, '')
        Puppet.settings.override_default(:vendormoduledir, '')

        Puppet.initialize_settings(cli)
        Puppet.settings[:hiera_config] = hiera_config

        # Use a special logdest that serializes all log messages and their level to stderr.
        Puppet::Util::Log.newdestination(:stderr)
        Puppet.settings[:log_level] = @log_level
        yield
      end
    end

    def generate_ast(code, filename = nil)
      with_puppet_settings do
        Puppet::Pal.in_tmp_environment("bolt_parse") do |pal|
          pal.with_catalog_compiler do |compiler|
            ast = compiler.parse_string(code, filename)
            Puppet::Pops::Serialization::ToDataConverter.convert(ast,
                                                                 rich_data: true,
                                                                 symbol_to_string: true)
          end
        end
      end
    end

    def setup_inventory(inventory)
      config = Bolt::Config.default
      plugins = Bolt::Plugin.setup(config, nil, nil, Bolt::Analytics::NoopClient.new)
      config.overwrite_transport_data(inventory['config']['transport'],
                                      Bolt::Util.symbolize_top_level_keys(inventory['config']['transports']))

      Bolt::Inventory.create_version(inventory['data'], config, plugins)
    end

    def compile_catalog(request)
      pal_main = request['code_ast'] || request['code_string']
      target = request['target']
      pdb_client = Bolt::PuppetDB::Client.new(Bolt::PuppetDB::Config.new(request['pdb_config']))
      options = request['puppet_config'] || {}

      with_puppet_settings(request['hiera_config']) do
        Puppet[:rich_data] = true
        Puppet[:node_name_value] = target['name']
        env_conf = { modulepath: request['modulepath'] || [],
                     facts: target['facts'] || {} }
        env_conf[:variables] = request['future'] ? {} : target['variables']
        Puppet::Pal.in_tmp_environment('bolt_catalog', env_conf) do |pal|
          inv = if request['future']
                  Bolt::ApplyInventory.new(request['config'])
                else
                  setup_inventory(request['inventory'])
                end
          Puppet.override(bolt_pdb_client: pdb_client,
                          bolt_inventory: inv) do
            Puppet.lookup(:pal_current_node).trusted_data = target['trusted']
            pal.with_catalog_compiler do |compiler|
              if request['future']
                # This needs to happen inside the catalog compiler so loaders are initialized for loading
                vars = Puppet::Pops::Serialization::FromDataConverter.convert(request['plan_vars'])
                pal.send(:add_variables, compiler.send(:topscope), vars.merge(target['variables']))
              end

              # Configure language strictness in the CatalogCompiler. We want Bolt to be able
              # to compile most Puppet 4+ manifests, so we default to allowing deprecated functions.
              Puppet[:strict] = options['strict'] || :warning
              Puppet[:strict_variables] = options['strict_variables'] || false
              ast = Puppet::Pops::Serialization::FromDataConverter.convert(pal_main)
              # This will be a Program when running via `bolt apply`, but will
              # only be a subset of the AST when compiling an apply block in a
              # plan. In that case, we need to discover the definitions (which
              # would ordinarily be stored on the Program) and construct a Program object.
              unless ast.is_a?(Puppet::Pops::Model::Program)
                # Node definitions must be at the top level of the apply block.
                # That means the apply body either a) consists of just a
                # NodeDefinition, b) consists of a BlockExpression which may
                # contain NodeDefinitions, or c) doesn't contain NodeDefinitions.
                definitions = if ast.is_a?(Puppet::Pops::Model::BlockExpression)
                                ast.statements.select { |st| st.is_a?(Puppet::Pops::Model::NodeDefinition) }
                              elsif ast.is_a?(Puppet::Pops::Model::NodeDefinition)
                                [ast]
                              else
                                []
                              end
                ast = Puppet::Pops::Model::Factory.PROGRAM(ast, definitions, ast.locator).model
              end
              compiler.evaluate(ast)
              compiler.instance_variable_get(:@internal_compiler).send(:evaluate_ast_node)
              compiler.compile_additions
              compiler.with_json_encoding(&:encode)
            end
          end
        end
      end
    end
  end
end
