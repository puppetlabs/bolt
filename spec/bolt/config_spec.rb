# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config'

describe Bolt::Config do
  let(:config) do
    conf = Bolt::Config.new
    allow(conf).to receive(:boltdir).and_return(File.join(Dir.tmpdir, rand(1000).to_s))
    conf
  end

  describe "when initializing" do
    it "accepts keyword values" do
      config = Bolt::Config.new(concurrency: 200)
      expect(config.concurrency).to eq(200)
    end

    it "uses a default value when none is given" do
      config = Bolt::Config.new
      expect(config.concurrency).to eq(100)
    end

    it "does not use a default value when nil is given" do
      config = Bolt::Config.new(concurrency: nil)
      expect(config.concurrency).to eq(nil)
    end

    it "rejects unknown keys" do
      expect {
        Bolt::Config.new(what: 'why')
      }.to raise_error(NameError)
    end
  end

  describe "deep_clone" do
    let(:conf) { config.deep_clone }

    {
      concurrency: -1,
      modulepath: '/foo',
      transport: 'anything',
      format: 'other'
    }.each do |k, v|
      it "updates #{k} in the copy to #{v}" do
        conf[k] = v
        expect(conf[k]).to eq(v)
        expect(config[k]).not_to eq(v)
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
          conf[:transports][transport][key] = false
          expect(conf[:transports][transport][key]).to eq(false)
          expect(config[:transports][transport][key]).not_to eq(false)
        end
      end
    end
  end

  describe "load_file" do
    let(:boltdir_path) { File.expand_path(File.join(config.boltdir, 'bolt.yaml')) }
    let(:default_path) { File.expand_path(File.join('~', '.puppetlabs', 'bolt.yaml')) }
    let(:alt_path) { File.expand_path(File.join('~', '.puppetlabs', 'bolt.yml')) }
    let(:hiera_path) { File.expand_path(File.join(config.boltdir, 'hiera.yaml')) }

    before(:each) do
      expect(File).to receive(:exist?).with(boltdir_path).and_return(false)
    end

    context 'with hiera defaults' do
      before(:each) do
        expect(File).to receive(:open).with(hiera_path, 'r:UTF-8')
        expect(File).to receive(:exist?).with(hiera_path)
      end

      it "loads from a default file" do
        expect(File).to receive(:exist?).with(default_path).twice.and_return(true)
        expect(File).to receive(:open).with(default_path, 'r:UTF-8').and_raise(Errno::ENOENT)
        config.load_file(nil)
      end

      it "falls back to the old default file" do
        expect(File).to receive(:exist?).with(default_path).and_return(false)
        expect(File).to receive(:exist?).with(alt_path).twice.and_return(true)
        expect(File).to receive(:open).with(alt_path, 'r:UTF-8').and_raise(Errno::ENOENT)
        config.load_file(nil)
      end

      it "warns if the default exists, and uses the new default" do
        expect(File).to receive(:exist?).with(default_path).twice.and_return(true)
        expect(File).to receive(:open).with(default_path, 'r:UTF-8').and_raise(Errno::ENOENT)

        config.load_file(nil)

        expect(@log_output.readline).to match(/WARN.*Found configfile at deprecated location #{default_path}/)
      end
    end

    it "loads from the specified file" do
      path = 'does not exist'
      expanded_path = File.expand_path(path)

      allow(File).to receive(:exist?).with(default_path)
      allow(File).to receive(:exist?).with(alt_path)
      expect(File).to receive(:open).with(expanded_path, 'r:UTF-8').and_raise(Errno::ENOENT)
      expect { config.load_file(path) }.to raise_error(Bolt::FileError)
    end
  end

  describe "validate" do
    it "does not accept invalid log levels" do
      config = Bolt::Config.new(
        log: {
          'file:/bolt.log' => { level: :foo }
        }
      )
      expect { config.validate }.to raise_error(
        'level of log file:/bolt.log must be one of: debug, info, notice, warn, error, fatal, any; received foo'
      )
    end

    it "does not accept invalid append flag values" do
      config = Bolt::Config.new(
        log: {
          'file:/bolt.log' => { append: :foo }
        }
      )
      expect { config.validate }.to raise_error('append flag of log file:/bolt.log must be a Boolean, received foo')
    end

    it "accepts integers for connection-timeout" do
      config = Bolt::Config.new(
        transports: {
          ssh: { 'connect-timeout' => 42 },
          winrm: { 'connect-timeout' => 999 },
          pcp: {}
        }
      )
      expect { config.validate }.not_to raise_error
    end

    it "does not accept values that are not integers" do
      config = Bolt::Config.new(
        transports: {
          ssh: { 'connect-timeout' => '42s' }
        }
      )
      expect { config.validate }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for host-key-check" do
      config = {
        transports: {
          ssh: { 'host-key-check' => false }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept host-key-check that is not a boolean" do
      config = {
        transports: {
          ssh: { 'host-key-check' => 'false' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a private-key hash" do
      config = {
        transports: {
          ssh: { 'private-key' => { 'key-data' => "foo" } }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept a private-key hash without data" do
      config = {
        transports: {
          ssh: { 'private-key' => { 'not-data' => "foo" } }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does accepts an array for run-as-command" do
      config = {
        transports: {
          ssh: { 'run-as-command' => ['sudo -n'] }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept a non-array for run-as-command" do
      config = {
        transports: {
          ssh: { 'run-as-command' => 'sudo -n' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for ssl" do
      config = {
        transports: {
          winrm: { 'ssl' => false }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept ssl that is not a boolean" do
      config = {
        transports: {
          winrm: { 'ssl' => 'false' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for ssl-verify" do
      config = {
        transports: {
          winrm: { 'ssl-verify' => false }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept ssl-verify that is not a boolean" do
      config = {
        transports: {
          winrm: { 'ssl-verify' => 'false' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "accepts a boolean for local-validation" do
      config = {
        transports: {
          pcp: { 'local-validation' => true }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept local-validation that is not a boolean" do
      config = {
        transports: {
          pcp: { 'local-validation' => 'false' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does not accept negative concurrency" do
      config = { concurrency: -1 }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does not accept zero concurrency" do
      config = { concurrency: 0 }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does not accept string concurrency" do
      config = { concurrency: '1' }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "accepts positive concurrency" do
      config = { concurrency: 1 }
      Bolt::Config.new(config).validate
    end

    it "does not accept negative compile-concurrency" do
      config = { 'compile-concurrency': -1 }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does not accept zero compile-concurrency" do
      config = { 'compile-concurrency': 0 }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does not accept large compile-concurrency" do
      config = { 'compile-concurrency': 1000000 }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "does not accept string compile-concurrency" do
      config = { 'compile-concurrency': '1' }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::ValidationError)
    end

    it "accepts positive compile-concurrency" do
      config = { 'compile-concurrency': 1 }
      Bolt::Config.new(config).validate
    end
  end

  describe 'boltdir' do
    let(:pwd) { File.dirname(boltdir_path) }
    let(:config) { Bolt::Config.new(pwd: pwd) }
    let(:boltdir_path) { File.join(@tmpdir, "foo", "Boltdir") }

    around(:each) do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        FileUtils.mkdir_p(boltdir_path)
        example.run
      end
    end

    it 'find the boltdir next to itself' do
      expect(config.boltdir).to eq(boltdir_path)
    end

    context 'when inside the boltdir' do
      let(:pwd) { boltdir_path }
      it 'find the boltdir next to itself' do
        expect(config.boltdir).to eq(boltdir_path)
      end
    end

    context 'when inside an inside a niece' do
      let(:pwd) { File.join(@tmpdir, 'foo', 'bar') }

      it 'find the boltdir from an existant dir' do
        FileUtils.mkdir_p(pwd)
        expect(config.boltdir).to eq(boltdir_path)
      end

      it 'find the boltdir from a non-existant dir' do
        expect(config.boltdir).to eq(boltdir_path)
      end
    end

    context 'when in a grandparent' do
      let(:pwd) { @tmpdir }
      it 'does not find the boltdir' do
        # Don't assert nil to be robust against a boltdir above tmp
        expect(config.boltdir).not_to eq(boltdir_path)
      end
    end
  end

  describe 'default_hiera' do
    let(:tmpdir) { Dir.mktmpdir }

    it 'sets default hiera path when boltdir is specified' do
      boltdir_path = File.join(tmpdir, "foo", "Boltdir")
      FileUtils.mkdir_p(File.join(tmpdir, "foo", "Boltdir"))
      config = Bolt::Config.new(pwd: File.dirname(boltdir_path))
      config.update({})
      expect(config[:'hiera-config']).to eq("#{config.boltdir}/hiera.yaml")
    end

    it 'sets default hiera path for default boltdir' do
      config = Bolt::Config.new(pwd: tmpdir)
      config.update({})
      expect(config[:'hiera-config']).to eq("#{config.boltdir}/hiera.yaml")
    end
  end
end
