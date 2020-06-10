# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'

describe Bolt::Config do
  let(:project) { Bolt::Project.new({}, @tmpdir) }
  let(:system_path) { Pathname.new(File.join(Bolt::Project.system_path, 'bolt.yaml')) }
  let(:user_path) { Pathname.new(File.expand_path(File.join('~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml'))) }

  around(:each) do |example|
    Dir.mktmpdir("foo") do |tmpdir|
      @tmpdir = Pathname.new(File.join(tmpdir, "validprojectname")).to_s
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
  end

  describe "::from_project" do
    it "loads from the project config file if present" do
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(project.config_file, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(system_path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(user_path, 'config')

      Bolt::Config.from_project(project)
    end

    context "when loading user level config fails" do
      let(:user_path) do
        Pathname.new(File.expand_path(['~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml'].join(File::SEPARATOR)))
      end

      it "doesn't load user level config and continues" do
        allow(File).to receive(:join).and_call_original
        allow(File)
          .to receive(:join)
          .with('~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml')
          .and_raise(ArgumentError, "couldn't find login name -- expanding `~'")

        expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(project.config_file, 'config')
        expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(system_path, 'config')
        expect(Bolt::Util).not_to receive(:read_optional_yaml_hash).with(user_path, 'config')

        Bolt::Config.from_project(project)
      end
    end

    it 'prefers bolt-project.yaml to bolt.yaml with config' do
      FileUtils.mkdir_p(@tmpdir)
      File.write(File.join(@tmpdir, 'bolt.yaml'), { 'format' => 'json' }.to_yaml)
      File.write(File.join(@tmpdir, 'bolt-project.yaml'), { 'format' => 'human' }.to_yaml)

      config = Bolt::Config.from_project(Bolt::Project.create_project(@tmpdir))
      expect(config.data['format']).to eq('human')
      expect(config.project.config_file.to_s).to eq(File.join(@tmpdir, 'bolt-project.yaml'))
    end

    # This should be removed when bolt.yaml deprecation is removed
    it 'prefers bolt.yaml to bolt-project.yaml with no config' do
      FileUtils.mkdir_p(@tmpdir)
      File.write(File.join(@tmpdir, 'bolt.yaml'), { 'format' => 'json' }.to_yaml)
      File.write(File.join(@tmpdir, 'bolt-project.yaml'), { 'name' => 'human' }.to_yaml)

      config = Bolt::Config.from_project(Bolt::Project.create_project(@tmpdir))
      expect(config.data['format']).to eq('json')
      expect(config.project.config_file.to_s).to eq(File.join(@tmpdir, 'bolt.yaml'))
    end
  end

  describe "::from_file" do
    let(:path) { File.expand_path('/path/to/config') }
    let(:proj_path) { Bolt::Util.windows? ? "D:/path/to/bolt-project.yaml" : "/path/to/bolt-project.yaml" }

    it 'loads from the specified config file' do
      expect(Bolt::Util).to receive(:read_yaml_hash).with(path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(system_path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash).with(user_path, 'config')
      expect(Bolt::Util).to receive(:read_optional_yaml_hash)
        .with(proj_path, "project")
        .and_return({})

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
      config = Bolt::Config.new(project, 'modulepath' => modules.upcase)
      expect(config.matching_paths(config.modulepath)).to include(modules)
    end

    it "does not accept invalid log levels" do
      config = {
        'log' => {
          'file:/bolt.log' => { 'level' => :foo }
        }
      }

      expect { Bolt::Config.new(project, config) }.to raise_error(
        /level of log file:.* must be one of debug, info, notice, warn, error, fatal, any; received foo/
      )
    end

    it "does not accept invalid append flag values" do
      config = {
        'log' => {
          'file:/bolt.log' => { 'append' => :foo }
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
      Bolt::Config.new(project, [
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
      expect(config.transports['ssh'].to_h).to include(
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
