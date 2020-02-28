# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'

describe Bolt::Config do
  let(:boltdir) { Bolt::Boltdir.new(File.join(Dir.tmpdir, rand(1000).to_s)) }
  let(:system_path) {
    if Bolt::Util.windows?
      Pathname.new(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'bolt', 'etc', 'bolt.yaml'))
    else
      Pathname.new(File.join('/etc', 'puppetlabs', 'bolt', 'bolt.yaml'))
    end
  }
  let(:user_path) { Pathname.new(File.expand_path(File.join('~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml'))) }

  describe "when initializing" do
    it "accepts string values for config data" do
      config = Bolt::Config.new(boltdir, 'concurrency' => 200)
      expect(config.concurrency).to eq(200)
    end

    it "accepts keyword values for overrides" do
      config = Bolt::Config.new(boltdir, {}, concurrency: 200)
      expect(config.concurrency).to eq(200)
    end

    it "overrides config values with overrides" do
      config = Bolt::Config.new(boltdir, { 'concurrency' => 200 }, concurrency: 100)
      expect(config.concurrency).to eq(100)
    end

    it "treats relative modulepath as relative to Boltdir" do
      module_dirs = %w[site modules]
      config = Bolt::Config.new(boltdir, 'modulepath' => module_dirs.join(File::PATH_SEPARATOR))
      expect(config.modulepath).to eq(module_dirs.map { |dir| (boltdir.path + dir).to_s })
    end

    it "accepts an array for modulepath" do
      module_dirs = %w[site modules]
      config = Bolt::Config.new(boltdir, 'modulepath' => module_dirs)
      expect(config.modulepath).to eq(module_dirs.map { |dir| (boltdir.path + dir).to_s })
    end
  end

  describe "::from_boltdir" do
    it "loads from the boltdir config file if present" do
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(boltdir.config_file, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(system_path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(user_path, 'config')

      Bolt::Config.from_boltdir(boltdir)
    end
  end

  describe "::from_file" do
    let(:path) { File.expand_path('/path/to/config') }

    it 'loads from the specified config file' do
      expect(Bolt::Util).to receive(:read_yaml_hash).with(path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(system_path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(user_path, 'config')

      Bolt::Config.from_file(path)
    end

    it "fails if the config file doesn't exist" do
      expect(File).to receive(:open).with(path, anything).and_raise(Errno::ENOENT)

      expect do
        Bolt::Config.from_file(path)
      end.to raise_error(Bolt::FileError)
    end
  end

  describe "validate" do
    it "returns suggested paths when path case is incorrect" do
      modules = File.expand_path('modules')
      config = Bolt::Config.new(boltdir, 'modulepath' => modules.upcase)
      expect(config.matching_paths(config.modulepath)).to include(modules)
    end

    it "does not accept invalid log levels" do
      config = {
        'log' => {
          'file:/bolt.log' => { 'level' => :foo }
        }
      }

      expect { Bolt::Config.new(boltdir, config) }.to raise_error(
        /level of log file:.* must be one of debug, info, notice, warn, error, fatal, any; received foo/
      )
    end

    it "does not accept invalid append flag values" do
      config = {
        'log' => {
          'file:/bolt.log' => { 'append' => :foo }
        }
      }

      expect { Bolt::Config.new(boltdir, config) } .to raise_error(
        /append flag of log file:.* must be a Boolean, received Symbol :foo/
      )
    end
  end

  describe 'expanding paths' do
    it "expands inventoryfile relative to boltdir" do
      data = {
        'inventoryfile' => 'targets.yml'
      }

      config = Bolt::Config.new(boltdir, data)
      expect(config.inventoryfile)
        .to eq(File.expand_path('targets.yml', boltdir.path))
    end
  end

  describe 'with future set' do
    let(:future_config) { { 'future' => true } }
    let(:config) { Bolt::Config.new(boltdir, future_config) }

    it 'logs a warning' do
      expect(config.warnings).to include(
        msg: /Configuration option 'future'/,
        option: 'future'
      )
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
      Bolt::Config.new(boltdir, [
                         { data: system_config },
                         { data: user_config },
                         { data: project_config }
                       ])
    }

    it 'performs a depth 2 shallow merge on plugins' do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
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
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
      expect(config.transports['ssh'].config).to include(
        'user' => 'bolt',
        'password' => 'bolt',
        'private-key' => %r{/path/to/key\z}
      )
    end

    it 'overwrites non-hash values' do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
      expect(config.transport).to eq('remote')
      expect(config.concurrency).to eq(5)
    end

    it 'performs a shallow merge on hash values' do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)
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
  end
end
