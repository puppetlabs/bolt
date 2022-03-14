# frozen_string_literal: true

require_relative '../bolt/apply_inventory'
require_relative '../bolt/apply_target'
require_relative '../bolt/config'
require_relative '../bolt/error'
require_relative '../bolt/inventory'
require_relative '../bolt/pal'
require_relative '../bolt/puppetdb'
require_relative '../bolt/util'

Bolt::PAL.load_puppet

require_relative 'catalog/logging'

module Bolt
  class Catalog
    def initialize(log_level = 'debug')
      @log_level = log_level
    end

    def with_puppet_settings(overrides = {})
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
        overrides.each do |setting, value|
          Puppet.settings[setting] = value
        end

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

    def compile_catalog(request)
      pdb_client = Bolt::PuppetDB::Client.new(Bolt::PuppetDB::Config.new(request['pdb_config']))
      project = request['project']
      bolt_project = Struct.new(:name, :path, :load_as_module?).new(project['name'],
                                                                    project['path'],
                                                                    project['load_as_module?'])
      inv = Bolt::ApplyInventory.new(request['config'])
      puppet_overrides = {
        bolt_pdb_client: pdb_client,
        bolt_inventory: inv,
        bolt_project: bolt_project
      }

      # Facts will be set by the catalog compiler, so we need to ensure
      # that any plan or target variables with the same name are not
      # passed into the apply block to avoid a redefinition error.
      # Filter out plan and target vars separately and raise a Puppet
      # warning if there are any collisions for either. Puppet warning
      # is the only way to log a message that will make it back to Bolt
      # to be printed.
      target = request['target']

      variables = {
        variables:        request['plan_vars'],
        target_variables: target['variables']
      }

      env_conf = {
        modulepath: request['modulepath'],
        facts:      target['facts']
      }

      puppet_settings = {
        node_name_value: target['name'],
        hiera_config:    request['hiera_config']
      }

      with_puppet_settings(puppet_settings) do
        Puppet::Pal.in_tmp_environment('bolt_catalog', **env_conf) do |pal|
          Puppet.override(puppet_overrides) do
            Puppet.lookup(:pal_current_node).trusted_data = target['trusted']
            pal.with_catalog_compiler(**variables) do |compiler|
              options = request['puppet_config'] || {}
              # Configure language strictness in the CatalogCompiler. We want Bolt to be able
              # to compile most Puppet 4+ manifests, so we default to allowing deprecated functions.
              Puppet[:strict] = options['strict'] || :warning
              Puppet[:strict_variables] = options['strict_variables'] || false

              pal_main = request['code_ast'] || request['code_string']
              ast = build_program(pal_main)
              compiler.evaluate(ast)
              compiler.evaluate_ast_node
              compiler.compile_additions
              compiler.with_json_encoding(&:encode)
            end
          end
        end
      end
    end

    def build_program(code)
      ast = Puppet::Pops::Serialization::FromDataConverter.convert(code)

      # This will be a Program when running via `bolt apply`, but will
      # only be a subset of the AST when compiling an apply block in a
      # plan. In that case, we need to discover the definitions (which
      # would ordinarily be stored on the Program) and construct a Program object.
      if ast.is_a?(Puppet::Pops::Model::Program)
        ast
      else
        # Node definitions must be at the top level of the apply block.
        # That means the apply body either a) consists of just a
        # NodeDefinition, b) consists of a BlockExpression which may
        # contain NodeDefinitions, or c) doesn't contain NodeDefinitions.
        definitions = case ast
                      when Puppet::Pops::Model::BlockExpression
                        ast.statements.select { |st| st.is_a?(Puppet::Pops::Model::NodeDefinition) }
                      when Puppet::Pops::Model::NodeDefinition
                        [ast]
                      else
                        []
                      end
        Puppet::Pops::Model::Factory.PROGRAM(ast, definitions, ast.locator).model
      end
    end
  end
end
