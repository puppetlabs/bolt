# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'

describe Bolt::Config do
  let(:boltdir) { Bolt::Boltdir.new(File.join(Dir.tmpdir, rand(1000).to_s)) }

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

  describe "deep_clone" do
    let(:config) { Bolt::Config.default }
    let(:conf) { config.deep_clone }

    {
      concurrency: -1,
      transport: 'anything',
      format: 'other'
    }.each do |k, v|
      it "updates #{k} in the copy to #{v}" do
        conf.send("#{k}=", v)
        expect(conf.send(k)).to eq(v)
        expect(config.send(k)).not_to eq(v)
      end
    end

    [
      { ssh: 'host-key-check' },
      { winrm: 'ssl' },
      { winrm: 'ssl-verify' },
      { pcp: 'foo' }
    ].each do |hash|
      hash.each do |transport, key|
        it "updates #{transport} #{key} in the copy to false" do
          conf.transports[transport][key] = false
          expect(conf.transports[transport][key]).to eq(false)
          expect(config.transports[transport][key]).not_to eq(false)
        end
      end
    end
  end

  describe "::from_boltdir" do
    let(:default_path) { File.expand_path(File.join('~', '.puppetlabs', 'bolt.yaml')) }

    it "loads from the boltdir config file if present" do
      expect(Bolt::Util).to receive(:read_config_file).with(nil, [boltdir.config_file], 'config')

      Bolt::Config.from_boltdir(boltdir)
    end
  end

  describe "::from_file" do
    let(:path) { File.expand_path('/path/to/config') }

    it 'loads from the specified config file' do
      expect(Bolt::Util).to receive(:read_config_file).with(path, [], 'config')

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
        /level of log file:.* must be one of: debug, info, notice, warn, error, fatal, any; received foo/
      )
    end

    it "does not accept invalid append flag values" do
      config = {
        'log' => {
          'file:/bolt.log' => { 'append' => :foo }
        }
      }

      expect { Bolt::Config.new(boltdir, config) } .to raise_error(
        /append flag of log file:.* must be a Boolean, received foo/
      )
    end

    it "accepts integers for connection-timeout" do
      config = {
        'transports' => {
          'ssh' => { 'connect-timeout' => 42 },
          'winrm' => { 'connect-timeout' => 999 },
          'pcp' => {}
        }
      }
      expect { Bolt::Config.new(boltdir, config) }.not_to raise_error
    end

    it "does not accept values that are not integers" do
      config = {
        'ssh' => { 'connect-timeout' => '42s' }
      }

      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for host-key-check" do
      config = {
        'ssh' => { 'host-key-check' => false }
      }

      expect {
        Bolt::Config.new(boltdir, config)
      }.not_to raise_error
    end

    it "does not accept host-key-check that is not a boolean" do
      config = {
        'ssh' => { 'host-key-check' => 'false' }
      }
      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a private-key hash" do
      config = {
        'ssh' => { 'private-key' => { 'key-data' => "foo" } }
      }
      expect { Bolt::Config.new(boltdir, config) }.not_to raise_error
    end

    it "expands the private-key hash with 'future' set" do
      data = {
        'ssh' => { 'private-key' => 'my-private-key' },
        'future' => true
      }
      config = Bolt::Config.new(boltdir, data)
      expect(config.transports[:ssh]['private-key']).to eq(File.expand_path('my-private-key', boltdir.path))
    end

    it "does not accept a private-key hash without data" do
      config = {
        'ssh' => { 'private-key' => { 'not-data' => "foo" } }
      }
      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::ValidationError)
    end

    it "does accepts an array for run-as-command" do
      config = {
        'ssh' => { 'run-as-command' => ['sudo -n'] }
      }
      expect { Bolt::Config.new(boltdir, config) }.not_to raise_error
    end

    it "does not accept a non-array for run-as-command" do
      config = {
        'ssh' => { 'run-as-command' => 'sudo -n' }
      }
      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for ssl" do
      config = {
        'winrm' => { 'ssl' => false }
      }
      expect { Bolt::Config.new(boltdir, config) }.not_to raise_error
    end

    it "does not accept ssl that is not a boolean" do
      config = {
        'winrm' => { 'ssl' => 'false' }
      }
      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for ssl-verify" do
      config = {
        'winrm' => { 'ssl-verify' => false }
      }
      expect { Bolt::Config.new(boltdir, config) }.not_to raise_error
    end

    it "does not accept ssl-verify that is not a boolean" do
      config = {
        'winrm' => { 'ssl-verify' => 'false' }
      }
      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::ValidationError)
    end

    it "validates cacert file exists when 'ssl' is true" do
      config = {
        'winrm' => { 'ssl' => true, 'cacert' => 'does not exist' }
      }
      expect { Bolt::Config.new(boltdir, config) }.to raise_error(Bolt::FileError, /'does not exist'/)
    end

    it "ignores invalid cacert file when 'ssl' is false" do
      config = {
        'winrm' => { 'ssl' => false, 'cacert' => 'does not exist' }
      }
      expect { Bolt::Config.new(boltdir, config) }.not_to raise_error
    end
  end

  describe 'expanding paths' do
    it "expands cacert relative to boltdir" do
      expect(Bolt::Util)
        .to receive(:validate_file)
        .with('cacert', File.expand_path('ssl/ca.pem', boltdir.path))
        .and_return(true)

      data = {
        'winrm' => { 'ssl' => true, 'cacert' => 'ssl/ca.pem' },
        'future' => true
      }

      config = Bolt::Config.new(boltdir, data)
      expect(config.transports[:winrm]['cacert'])
        .to eq(File.expand_path('ssl/ca.pem', boltdir.path))
    end

    it "expands token-file relative to boltdir" do
      data = {
        'pcp' => { 'token-file' => 'token' },
        'future' => true
      }

      config = Bolt::Config.new(boltdir, data)
      expect(config.transports[:pcp]['token-file'])
        .to eq(File.expand_path('token', boltdir.path))
    end

    it "expands private-key relative to boltdir" do
      data = {
        'ssh' => { 'private-key' => 'secret/key' },
        'future' => true
      }

      config = Bolt::Config.new(boltdir, data)
      expect(config.transports[:ssh]['private-key'])
        .to eq(File.expand_path('secret/key', boltdir.path))
    end

    it "does not attempt to expand private-key when key-data is specified" do
      key_data = { 'key-data' => 'key content' }
      data = {
        'ssh' => {
          'private-key' => key_data
        },
        'future' => true
      }

      config = Bolt::Config.new(boltdir, data)
      expect(config.transports[:ssh]['private-key'])
        .to eq(key_data)
    end

    it "expands inventoryfile relative to boltdir" do
      data = {
        'inventoryfile' => 'targets.yml',
        'future' => true
      }

      config = Bolt::Config.new(boltdir, data)
      expect(config.inventoryfile)
        .to eq(File.expand_path('targets.yml', boltdir.path))
    end
  end
end
