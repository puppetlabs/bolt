# frozen_string_literal: true

require 'bolt/config'
require 'bolt/inventory/inventory'
require 'bolt/pal'
require 'bolt/plugin'
require 'bolt_spec/config'
require 'bolt_spec/files'

module BoltSpec
  module PAL
    include BoltSpec::Config
    include BoltSpec::Files

    def make_pal(modulepath = nil)
      modulepath ||= fixtures_path('modules')
      Bolt::PAL.new(Bolt::Config::Modulepath.new(modulepath), nil, nil)
    end

    def make_plugins(config = nil)
      config ||= make_config
      Bolt::Plugin.setup(config, nil)
    end

    def make_inventory(data = {})
      config = make_config
      plugins = make_plugins(config)
      Bolt::Inventory::Inventory.new(data, config.transport, config.transports, plugins)
    end

    def peval(code, pal, executor = nil, inventory = nil, pdb_client = nil)
      pal.in_plan_compiler(executor, inventory, pdb_client) do |c|
        c.evaluate_string(code)
      end
    end

    def mk_files(path, content)
      FileUtils.mkdir_p(path)
      content.each do |name, cont|
        full_path = File.join(path, name)
        if cont.is_a? Hash
          mk_files(full_path, cont)
        else
          File.open(full_path, 'w') { |f| f.write(cont) }
        end
      end
    end

    def pal_with_module_content(mods)
      Dir.mktmpdir do |tmpdir|
        mk_files(tmpdir, mods)
        pal = Bolt::PAL.new(Bolt::Config::Modulepath.new(tmpdir), nil, nil)
        yield pal
      end
    end
  end
end
