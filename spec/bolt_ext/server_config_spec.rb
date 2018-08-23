# frozen_string_literal: true

require 'spec_helper'
require 'bolt_ext/server_config'

describe TransportConfig do
  let(:missingconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'non-existent.conf') }
  let(:emptyconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'empty-bolt-server.conf') }
  let(:globalconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'global-bolt-server.conf') }
  let(:localconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'local-bolt-server.conf') }
  let(:requiredconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'required-bolt-server.conf') }

  it "reads from default paths" do
    expect(Hocon).to receive(:load).with('/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf').and_return({})
    expect(Hocon).to receive(:load).with(File.join(ENV['HOME'].to_s, ".puppetlabs", "bolt-server.conf")).and_return({})
    expect { TransportConfig.new }.to raise_error(Bolt::ValidationError, /You must configure/)
  end

  context 'with global config' do
    let(:config) { TransportConfig.new(globalconfig, missingconfig) }

    it 'reads host' do
      expect(config.host).to eq('10.0.0.1')
    end

    it 'reads port' do
      expect(config.port).to eq(12345)
    end

    it 'reads loglevel' do
      expect(config.loglevel).to eq('debug')
    end

    it 'reads logfile' do
      expect(config.logfile).to eq('/var/log/global')
    end
  end

  context 'with local config' do
    let(:config) { TransportConfig.new(missingconfig, localconfig) }

    it 'reads host' do
      expect(config.host).to eq('0.0.0.0')
    end

    it 'reads port' do
      expect(config.port).to eq(6789)
    end

    it 'reads loglevel' do
      expect(config.loglevel).to eq('info')
    end

    it 'reads logfile' do
      expect(config.logfile).to eq('/var/log/local')
    end
  end

  context 'with local and global config' do
    let(:config) { TransportConfig.new(globalconfig, localconfig) }

    it 'local host overrides global' do
      expect(config.host).to eq('0.0.0.0')
    end

    it 'local port overrides global' do
      expect(config.port).to eq(6789)
    end

    it 'local loglevel overrides global' do
      expect(config.loglevel).to eq('info')
    end

    it 'local logfile overrides global' do
      expect(config.logfile).to eq('/var/log/local')
    end
  end

  it "accepts only required config" do
    config = TransportConfig.new(requiredconfig, missingconfig)
    expect(config.host).to eq('127.0.0.1')
    expect(config.port).to be(62658)
    expect(config.loglevel).to eq('notice')
    expect(config.logfile).to eq(nil)
  end

  it "reads ssl keys from config" do
    config = TransportConfig.new(globalconfig, missingconfig)
    expect(config.ssl_cert).to eq('spec/fixtures/ssl/cert.pem')
    expect(config.ssl_key).to eq('spec/fixtures/ssl/key.pem')
    expect(config.ssl_ca_cert).to eq('spec/fixtures/ssl/ca.pem')
  end

  it "errors when a required key is not present" do
    expect {
      TransportConfig.new(emptyconfig, missingconfig)
    }.to raise_error(Bolt::ValidationError, /You must configure/)
  end

  it "errors when a specified file does not exist" do
  end
end
