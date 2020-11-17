# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'
require 'bolt_spec/project'

describe Bolt::Config do
  include BoltSpec::Project

  let(:system_path)   { Bolt::Config.system_path }
  let(:user_path)     { Bolt::Config.user_path }
  let(:config_name)   { Bolt::Config::BOLT_CONFIG_NAME }
  let(:defaults_name) { Bolt::Config::BOLT_DEFAULTS_NAME }
  let(:logfile)       { 'bolt.log' }

  around(:each) do |example|
    with_project do
      example.run
    end
  end

  describe "when initializing" do
    it "accepts string values for config data" do
      config = Bolt::Config.new(project, 'concurrency' => 200)
      expect(config.concurrency).to eq(200)
    end

    it "accepts keyword values for overrides" do
      config = Bolt::Config.new(project, {}, concurrency: 200)
      expect(config.concurrency).to eq(200)
    end

    it "overrides config values with overrides" do
      config = Bolt::Config.new(project, { 'concurrency' => 200 }, concurrency: 100)
      expect(config.concurrency).to eq(100)
    end

    it "treats relative modulepath as relative to project" do
      module_dirs = %w[site modules]
      config = Bolt::Config.new(project, 'modulepath' => module_dirs.join(File::PATH_SEPARATOR))
      expect(config.modulepath).to eq(module_dirs.map { |dir| (project.path + dir).to_s })
    end

    it "accepts an array for modulepath" do
      module_dirs = %w[site modules]
      config = Bolt::Config.new(project, 'modulepath' => module_dirs)
      expect(config.modulepath).to eq(module_dirs.map { |dir| (project.path + dir).to_s })
    end

    it 'modifies concurrency if ulimit is low', :ssh do
      allow(Etc).to receive(:sysconf).with(Etc::SC_OPEN_MAX).and_return(256)
      config = Bolt::Config.new(project, {})
      expect(config.modified_concurrency).to eq(true)
      expect(config.concurrency).to eq(36)
    end

    it 'sets the default transport from an override' do
      config = Bolt::Config.new(project, {}, transport: 'winrm')
      expect(config.transport).to eq('winrm')
    end
  end

  describe "::from_project" do
    it "loads from the project config file if present" do
      allow(Bolt::Util).to receive(:read_optional_yaml_hash).and_return({})
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(project.config_file, 'config')

      Bolt::Config.from_project(project)
    end

    context "when loading user level config fails" do
      let(:user_path) do
        Pathname.new(File.expand_path(['~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml'].join(File::SEPARATOR)))
      end

      it "doesn't load user level config and continues" do
        allow(Bolt::Config).to receive(:user_path).and_return(nil)
        allow(Bolt::Util).to receive(:read_optional_yaml_hash).and_return({})
        expect(Bolt::Util).not_to receive(:read_optional_yaml_hash).with(user_path, 'config')

        Bolt::Config.from_project(project)
      end
    end

    it 'prefers bolt-project.yaml to bolt.yaml with config' do
      File.write(File.join(@tmpdir, 'bolt.yaml'), { 'format' => 'json' }.to_yaml)
      File.write(File.join(@tmpdir, 'bolt-project.yaml'), { 'format' => 'human' }.to_yaml)

      config = Bolt::Config.from_project(Bolt::Project.create_project(@tmpdir))
      expect(config.data['format']).to eq('human')
      expect(config.project.config_file.to_s).to eq(File.join(@tmpdir, 'bolt-project.yaml'))
    end

    # This should be removed when bolt.yaml deprecation is removed
    it 'prefers bolt.yaml to bolt-project.yaml with no config' do
      File.write(File.join(@tmpdir, 'bolt.yaml'), { 'format' => 'json' }.to_yaml)
      File.write(File.join(@tmpdir, 'bolt-project.yaml'), { 'name' => 'human' }.to_yaml)

      config = Bolt::Config.from_project(Bolt::Project.create_project(@tmpdir))
      expect(config.data['format']).to eq('json')
      expect(config.project.config_file.to_s).to eq(File.join(@tmpdir, 'bolt.yaml'))
    end
  end

  describe "::from_file" do
    let(:path) { File.expand_path('/path/to/config.yaml') }
    let(:dir) { Bolt::Util.windows? ? "D:/path/to" : "/path/to" }
    let(:proj_path) { File.join(dir, "bolt-project.yaml") }

    it 'loads from the specified config file' do
      allow(File).to receive(:directory?).with(Pathname.new(dir)).and_return(true)
      allow(Bolt::Util).to receive(:read_optional_yaml_hash).and_return({})
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
      expect(Bolt::Util).to receive(:read_yaml_hash)
        .with(path, 'config')
        .and_return({})
      expect(Bolt::Util).to receive(:read_optional_yaml_hash)
        .with(proj_path, "project")
        .and_return({})

      Bolt::Config.from_file(path)
    end

    it "fails if the config file doesn't exist" do
      allow(File).to receive(:directory?).with(Pathname.new(dir)).and_return(true)
      expect(File).to receive(:open).with(path, anything).and_raise(Errno::ENOENT)

      expect do
        Bolt::Config.from_file(path)
      end.to raise_error(Bolt::FileError)
    end
  end

  describe '::load_defaults' do
    shared_examples 'config defaults' do
      it 'defaults to bolt.yaml' do
        allow(File).to receive(:exist?)
        allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
        allow(File).to receive(:exist?).with(path + defaults_name).and_return(false)
        allow(File).to receive(:exist?).with(path + config_name).and_return(true)
        expect(Bolt::Util).to receive(:read_yaml_hash).with(path + config_name, 'config')

        Bolt::Config.load_defaults(project)
      end

      it 'warns when using bolt.yaml' do
        allow(File).to receive(:exist?)
        allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
        allow(File).to receive(:exist?).with(path + defaults_name).and_return(false)
        allow(File).to receive(:exist?).with(path + config_name).and_return(true)

        deps = Bolt::Config.load_defaults(project).flat_map { |config| config[:deprecations] }
        # All the deprecation messages + types
        expect(deps.map(&:values).flatten).to include(/bolt.yaml is deprecated/)
      end

      it 'loads bolt-defaults.yaml if present' do
        allow(File).to receive(:exist?)
        allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
        allow(File).to receive(:exist?).with(path + defaults_name).and_return(true)
        expect(Bolt::Util).to receive(:read_yaml_hash).with(path + defaults_name, 'config')

        Bolt::Config.load_defaults(project)
      end

      it 'loads nothing when bolt.yaml and bolt-defaults.yaml are not present' do
        allow(File).to receive(:exist?).and_return(false)
        expect(Bolt::Util).not_to receive(:read_yaml_hash)

        Bolt::Config.load_defaults(project)
      end
    end

    context 'system-level config' do
      let(:path) { system_path }

      include_examples 'config defaults'

      it 'does not load bolt.yaml if already loaded by project' do
        allow(File).to receive(:exist?)
        allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
        allow(File).to receive(:exist?).with(path + defaults_name).and_return(false)
        allow(project).to receive(:config_file).and_return(path + config_name)
        expect(Bolt::Util).not_to receive(:read_yaml_hash).with(path + config_name, 'config')

        Bolt::Config.load_defaults(project)
      end
    end

    context 'user-level config' do
      let(:path) { user_path }

      include_examples 'config defaults'
    end
  end

  describe '::load_bolt_defaults_yaml' do
    let(:path) { user_path }

    it 'warns when bolt.yaml is also present' do
      allow(File).to receive(:exist?)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
      allow(File).to receive(:exist?).with(path + config_name).and_return(true)

      logs = Bolt::Config.load_bolt_defaults_yaml(path)[:logs]
      expect(logs).to include(warn: /Detected multiple configuration files/)
    end

    it 'warns when inventory config keys are present' do
      allow(File).to receive(:exist?)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return(Bolt::Config::INVENTORY_OPTIONS.dup)

      logs = Bolt::Config.load_bolt_defaults_yaml(path)[:logs]
      expect(logs).to include(warn: /Unsupported inventory configuration/)
    end

    it 'warns when project config keys are present' do
      project_config = { 'name' => 'myproject' }

      allow(File).to receive(:exist?)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return(project_config)

      logs = Bolt::Config.load_bolt_defaults_yaml(path)[:logs]
      expect(logs).to include(warn: /Unsupported project configuration/)
    end

    it 'puts keys under inventory-config at the top level' do
      allow(File).to receive(:exist?)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return(
        'inventory-config' => {
          'transport' => 'ssh',
          'ssh' => {
            'password' => 'bolt'
          }
        }
      )

      data = Bolt::Config.load_bolt_defaults_yaml(path)[:data]
      expect(data).to include(
        'transport' => 'ssh',
        'ssh' => {
          'password' => 'bolt'
        }
      )
    end
  end

  describe "validate" do
    it "returns suggested paths when path case is incorrect" do
      modules = File.expand_path('modules')
      config = Bolt::Config.new(project, 'modulepath' => modules.upcase)
      expect(config.matching_paths(config.modulepath)).to include(modules)
    end

    it "does not accept invalid log levels" do
      config = {
        'log' => {
          "file:#{logfile}" => { 'level' => :foo }
        }
      }

      expect { Bolt::Config.new(project, config) }.to raise_error(
        /level of log file:.* must be one of .*; received foo/
      )
    end

    it "does not accept invalid append flag values" do
      config = {
        'log' => {
          "file:#{logfile}" => { 'append' => :foo }
        }
      }

      expect { Bolt::Config.new(project, config) }.to raise_error(
        /append flag of log file:.* must be a Boolean, received Symbol :foo/
      )
    end
  end

  describe 'expanding paths' do
    it "expands inventoryfile relative to project" do
      data = {
        'inventoryfile' => 'targets.yml'
      }

      config = Bolt::Config.new(project, data)
      expect(config.inventoryfile)
        .to eq(File.expand_path('targets.yml', project.path))
    end
  end

  describe 'with future set' do
    let(:future_config) { { 'future' => true } }
    let(:config) { Bolt::Config.new(project, future_config) }

    it 'logs a warning' do
      expect(config.logs).to include(warn: /Configuration option 'future'/)
    end
  end

  describe 'merging config files' do
    let(:project_config) {
      {
        'transport' => 'remote',
        'ssh' => {
          'user' => 'bolt',
          'password' => 'bolt'
        },
        'plugins' => {
          'vault' => {
            'auth' => {
              'method' => 'userpass',
              'user' => 'bolt',
              'pass' => 'bolt'
            }
          }
        },
        'plugin_hooks' => {
          'puppet_library' => {
            'plugin' => 'puppet_agent',
            '_run_as' => 'root'
          }
        }
      }
    }

    let(:user_config) {
      {
        'transport' => 'winrm',
        'concurrency' => 5,
        'ssh' => {
          'user' => 'puppet',
          'private-key' => '/path/to/key'
        },
        'plugins' => {
          'aws_inventory' => {
            'credentials' => '~/aws/credentials'
          }
        },
        'plugin_hooks' => {
          'puppet_library' => {
            'plugin' => 'task',
            'task' => 'bootstrap'
          },
          'fake_hook' => {
            'plugin' => 'fake_plugin'
          }
        }
      }
    }

    let(:system_config) {
      {
        'ssh' => {
          'password' => 'puppet',
          'private-key' => {
            'key-data' => 'supersecretkey'
          }
        },
        'plugins' => {
          'vault' => {
            'server_url' => 'http://example.com',
            'cacert' => '/path/to/cert',
            'auth' => {
              'method' => 'token',
              'token' => 'supersecrettoken'
            }
          }
        },
        'log' => {
          '~/.puppetlabs/debug.log' => {
            'level' => 'debug',
            'append' => false
          }
        }
      }
    }

    let(:config) {
      Bolt::Config.new(project, [
                         { data: system_config, logs: [], deprecations: [] },
                         { data: user_config, logs: [], deprecations: [] },
                         { data: project_config, logs: [], deprecations: [] }
                       ])
    }

    it 'performs a depth 2 shallow merge on plugins' do
      expect(config.plugins).to eq(
        'vault' => {
          'server_url' => 'http://example.com',
          'cacert' => '/path/to/cert',
          'auth' => {
            'method' => 'userpass',
            'user' => 'bolt',
            'pass' => 'bolt'
          }
        },
        'aws_inventory' => {
          'credentials' => '~/aws/credentials'
        }
      )
    end

    it 'performs a deep merge on transport config' do
      expect(config.transports['ssh'].to_h).to include(
        'user' => 'bolt',
        'password' => 'bolt',
        'private-key' => %r{/path/to/key\z}
      )
    end

    it 'overwrites non-hash values' do
      expect(config.transport).to eq('remote')
      expect(config.concurrency).to eq(5)
    end

    it 'performs a shallow merge on hash values' do
      expect(config.plugin_hooks).to eq(
        'puppet_library' => {
          'plugin' => 'puppet_agent',
          '_run_as' => 'root'
        },
        'fake_hook' => {
          'plugin' => 'fake_plugin'
        }
      )
    end

    it 'removes log files that are disabled' do
      project_config['log'] = { '~/.puppetlabs/debug.log' => 'disable' }
      expect(config.log).not_to include('~/.puppetlabs/debug.log')
    end
  end

  describe '#modulepath' do
    let(:project_config)    { { 'modules' => [] } }
    let(:config)            { Bolt::Config.from_project(project) }
    let(:managed_moduledir) { (project_path + '.modules').to_s }
    let(:overrides)         { { 'modulepath' => managed_moduledir } }

    context 'with modules configured' do
      it 'appends the managed moduledir to the modulepath' do
        expect(config.modulepath[-1]).to eq(managed_moduledir)
      end

      it 'errors if the user configures the managed moduledir' do
        expect { Bolt::Config.from_project(project, overrides) }.to raise_error(Bolt::ValidationError)
      end
    end

    context 'with modules not configured' do
      before(:each) do
        delete_config
      end

      it 'does not append the managed moduledir to the modulepath' do
        expect(config.modulepath).not_to include(managed_moduledir)
      end

      it 'does not error if the user configured the managed moduledir' do
        expect { Bolt::Config.from_project(project, overrides) }.not_to raise_error
      end
    end
  end
end
