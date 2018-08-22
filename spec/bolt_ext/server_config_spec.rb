# frozen_string_literal: true

require 'spec_helper'
require 'bolt_ext/server-config'

describe TransportConfig do
  let(:emptyconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'empty-bolt-server.conf') }
  let(:globalconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'global-bolt-server.conf') }
  let(:localconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'local-bolt-server.conf') }
  let(:requiredconfig) { File.join(__dir__, '..', 'fixtures', 'configs', 'required-bolt-server.conf') }

  it "reads a port from 'global' config" do
    config = TransportConfig.new(globalconfig)
    expect(config.port).to be(12345)
  end

  it "reads a port from local config" do
    # This needs to have the empty config as the global config so that rspec
    # doesn't try to read /etc/puppetlabs/bolt-server/conf.d/bolt-server.conf
    config = TransportConfig.new(requiredconfig, localconfig)
    expect(config.port).to be(6789)
  end

  it "local config overrides global config" do
    config = TransportConfig.new(globalconfig, localconfig)
    expect(config.port).to be(6789)
  end

  it "accepts an empty config" do
    config = TransportConfig.new(requiredconfig)
    expect(config.port).to be(62658)
  end

  it "reads ssl keys from config" do
    config = TransportConfig.new(globalconfig)
    expect(config.ssl_cert).to eq('spec/fixtures/ssl/cert.pem')
    expect(config.ssl_key).to eq('spec/fixtures/ssl/key.pem')
    expect(config.ssl_ca_cert).to eq('spec/fixtures/ssl/ca.pem')
  end

  it "errors when a required key is not present" do
    expect { TransportConfig.new(emptyconfig) }.to raise_error(Bolt::ValidationError, /You must configure/)
  end

  it "errors when a specified file does not exist" do
  end
end
