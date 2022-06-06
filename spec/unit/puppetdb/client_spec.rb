# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/client'

describe Bolt::PuppetDB::Client do
  let(:client) { described_class.new(config: config, instances: instances) }

  let(:instance_name)    { 'other' }
  let(:default_instance) { double('default') }
  let(:named_instance)   { double(instance_name) }

  let(:config) do
    {
      'server_urls' => ["https://puppet.example.com:8081"],
      'cacert'      => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
      'token'       => '~/.puppetlabs/token'
    }
  end

  let(:instances) do
    {
      instance_name => {
        'server_urls' => ["https://puppet.example.com:8082"],
        'cacert'      => '/etc/puppetlabs/puppet/ssl/certs/other-ca.pem',
        'token'       => '~/.puppetlabs/other-token'
      }
    }
  end

  before(:each) do
    allow(Bolt::PuppetDB::Instance)
      .to receive(:new)
      .with(config: config, project: nil, load_defaults: true)
      .and_return(default_instance)

    allow(Bolt::PuppetDB::Instance)
      .to receive(:new)
      .with(config: instances[instance_name], project: nil)
      .and_return(named_instance)
  end

  context 'selecting an instance' do
    it 'yields the default instance when an instance is not specified' do
      expect(client.instance).to eq(default_instance)
    end

    it 'yields the named instance when an instance is specified' do
      expect(client.instance(instance_name)).to eq(named_instance)
    end

    it 'errors if the named instance is not configured' do
      expect { client.instance('fake-instance') }.to raise_error(
        Bolt::PuppetDBError,
        /PuppetDB instance 'fake-instance' has not been configured/
      )
    end
  end

  context '#send_command' do
    let(:command) { 'implode' }
    let(:version) { 5 }
    let(:payload) { {} }

    it 'sends a command to the default instance' do
      expect(default_instance).to receive(:send_command).with(command, version, payload).and_return(true)
      client.send_command(command, version, payload)
    end

    it 'sends a command to the named instance' do
      expect(named_instance).to receive(:send_command).with(command, version, payload).and_return(true)
      client.send_command(command, version, payload, instance_name)
    end
  end
end
