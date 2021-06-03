# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'
require 'bolt_spec/project'

describe Bolt::Config do
  include BoltSpec::Project

  let(:system_path)    { Bolt::Config.system_path }
  let(:user_path)      { Bolt::Config.user_path }
  let(:defaults_name)  { Bolt::Config::DEFAULTS_NAME }
  let(:logfile)        { 'bolt.log' }
  let(:project_config) { nil }
  let(:project)        { @project }
  let(:tmpdir)         { project.path.parent }

  around(:each) do |example|
    with_project(config: project_config) do |project|
      @project = project
      example.run
    end
  end

  describe "defaults" do
    let(:config) { Bolt::Config.new(project, {}) }

    it 'sets concurrency to 100' do
      expect(config.concurrency).to eq(100)
    end

    it 'sets compile-concurrency to number of processors' do
      expect(config.compile_concurrency).to eq(Etc.nprocessors)
    end

    it 'sets transport to ssh' do
      expect(config.transport).to eq('ssh')
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
      expect(config.modulepath).to include(*module_dirs.map { |dir| (project.path + dir).to_s })
    end

    it "accepts an array for modulepath" do
      module_dirs = %w[site modules]
      config = Bolt::Config.new(project, 'modulepath' => module_dirs)
      expect(config.modulepath).to include(*module_dirs.map { |dir| (project.path + dir).to_s })
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
    context "when loading user level config fails" do
      let(:user_path) do
        Pathname.new(File.expand_path(['~', '.puppetlabs', 'etc', 'bolt', 'bolt-defaults.yaml'].join(File::SEPARATOR)))
      end

      it "doesn't load user level config and continues" do
        allow(Bolt::Config).to receive(:user_path).and_return(nil)
        allow(Bolt::Util).to receive(:read_optional_yaml_hash).and_return({})
        expect(Bolt::Util).not_to receive(:read_optional_yaml_hash).with(user_path, 'config')

        Bolt::Config.from_project(project)
      end
    end
  end

  describe '::load_defaults' do
    shared_examples 'config defaults' do
      it 'loads bolt-defaults.yaml if present' do
        allow(File).to receive(:exist?)
        allow(Bolt::Util).to receive(:read_yaml_hash).and_return({})
        allow(File).to receive(:exist?).with(path + defaults_name).and_return(true)
        expect(Bolt::Util).to receive(:read_yaml_hash).with(path + defaults_name, 'config')

        Bolt::Config.load_defaults
      end

      it 'loads nothing when bolt-defaults.yaml is not present' do
        allow(File).to receive(:exist?).and_return(false)
        expect(Bolt::Util).not_to receive(:read_yaml_hash)

        Bolt::Config.load_defaults
      end
    end

    context 'system-level config' do
      let(:path) { system_path }

      include_examples 'config defaults'
    end

    context 'user-level config' do
      let(:path) { user_path }

      include_examples 'config defaults'
    end
  end

  describe '::load_bolt_defaults_yaml' do
    let(:path) { user_path }

    it 'warns when inventory config keys are present' do
      allow(File).to receive(:exist?)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return(Bolt::Config::INVENTORY_OPTIONS.dup)
      allow(Bolt::Logger).to receive(:warn)

      expect(Bolt::Logger).to receive(:warn).with(anything, /Unsupported inventory configuration/)

      Bolt::Config.load_bolt_defaults_yaml(path)
    end

    it 'warns when project config keys are present' do
      project_config = { 'name' => 'myproject' }

      allow(File).to receive(:exist?)
      allow(Bolt::Util).to receive(:read_yaml_hash).and_return(project_config)
      allow(Bolt::Logger).to receive(:warn)

      expect(Bolt::Logger).to receive(:warn).with(anything, /Unsupported project configuration/)

      Bolt::Config.load_bolt_defaults_yaml(path)
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

    it "does not accept inventory files that don't exist" do
      overrides = {
        'inventoryfile' => 'fake.yaml'
      }

      expect { Bolt::Config.new(project, [], overrides) }.to raise_error(
        Bolt::FileError,
        /The inventoryfile .* does not exist/
      )
    end
  end

  describe 'expanding paths' do
    it "expands inventoryfile relative to project" do
      overrides = {
        'inventoryfile' => 'targets.yml'
      }
      f = File.expand_path(File.join(project.path, 'targets.yml'))
      FileUtils.touch(f)

      config = Bolt::Config.new(project, [], overrides)
      expect(config.inventoryfile)
        .to eq(f)
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
        'plugin-hooks' => {
          'puppet_library' => {
            'plugin' => 'puppet_agent',
            '_run_as' => 'root'
          }
        },
        'disable-warnings' => ['foo']
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
        'plugin-hooks' => {
          'puppet_library' => {
            'plugin' => 'task',
            'task' => 'bootstrap'
          },
          'fake_hook' => {
            'plugin' => 'fake_plugin'
          }
        },
        'disable-warnings' => ['bar']
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
        },
        'disable-warnings' => ['baz']
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

    it 'concatenates disable-warnings' do
      expect(config.disable_warnings).to match_array(%w[foo bar baz])
    end

    it 'removes log files that are disabled' do
      project_config['log'] = { '~/.puppetlabs/debug.log' => 'disable' }
      expect(config.log).not_to include('~/.puppetlabs/debug.log')
    end

    context 'analytics' do
      it 'defaults to enabled' do
        expect(config.analytics).to eq(true)
      end

      it 'overrides a true value with false' do
        system_config['analytics']  = true
        project_config['analytics'] = false
        expect(config.analytics).to eq(false)
      end

      it 'does not override a false value' do
        system_config['analytics']  = false
        project_config['analytics'] = true
        expect(config.analytics).to eq(false)
      end
    end
  end

  describe '#modulepath' do
    let(:config)    { Bolt::Config.from_project(project) }
    let(:overrides) { { 'modulepath' => project.managed_moduledir.to_s } }

    context 'with modules configured' do
      let(:project_config) { { 'modules' => ['puppetlabs-yaml'] } }

      it 'appends the managed moduledir to the modulepath' do
        expect(config.modulepath[-1]).to eq(project.managed_moduledir.to_s)
      end

      it 'errors if the user configures the managed moduledir' do
        expect { Bolt::Config.from_project(project, overrides) }.to raise_error(Bolt::ValidationError)
      end
    end
  end
end
