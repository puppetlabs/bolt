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

  context 'with a named default instance' do
    let(:client) { described_class.new(config: config, instances: instances, default: instance_name) }

    it 'uses the named instance as the default' do
      expect(client.instance).to eq(named_instance)
    end

    it 'errors when the default name is not configured' do
      expect { described_class.new(config: config, instances: {}, default: 'missing') }
        .to raise_error(Bolt::PuppetDBError, /has not been configured/)
    end
  end

  context '#query_certnames' do
    it 'returns an empty array when query is nil' do
      expect(client.query_certnames(nil)).to eq([])
    end

    it 'returns certnames from query results' do
      allow(default_instance).to receive(:make_query)
        .and_return([{ 'certname' => 'host1' }, { 'certname' => 'host2' }, { 'certname' => 'host1' }])
      expect(client.query_certnames('nodes {}'))
        .to contain_exactly('host1', 'host2')
    end

    it 'errors when results do not contain a certname field' do
      allow(default_instance).to receive(:make_query).and_return([{ 'name' => 'host1' }])
      expect { client.query_certnames('nodes {}') }
        .to raise_error(Bolt::PuppetDBError, /certname/)
    end
  end

  context '#facts_for_node' do
    it 'returns an empty hash when certnames is empty' do
      expect(client.facts_for_node([])).to eq({})
    end

    it 'returns a hash of certname to facts' do
      allow(default_instance).to receive(:make_query).and_return(
        [{ 'certname' => 'host1', 'facts' => { 'os' => 'linux' } }]
      )
      expect(client.facts_for_node(['host1'])).to eq('host1' => { 'os' => 'linux' })
    end
  end

  context '#fact_values' do
    it 'returns an empty hash when certnames is empty' do
      expect(client.fact_values([], ['os'])).to eq({})
    end

    it 'returns an empty hash when facts list is empty' do
      expect(client.fact_values(['host1'], [])).to eq({})
    end

    it 'returns results grouped by certname' do
      allow(default_instance).to receive(:make_query).and_return(
        [{ 'certname' => 'host1', 'path' => 'os', 'value' => 'linux', 'environment' => 'prod', 'name' => 'os' }]
      )
      result = client.fact_values(['host1'], ['os'])
      expect(result.keys).to contain_exactly('host1')
    end
  end

  context '#make_query' do
    it 'delegates to the default instance' do
      expect(default_instance).to receive(:make_query).with('nodes {}', nil).and_return([])
      client.make_query('nodes {}')
    end

    it 'delegates to the named instance' do
      expect(named_instance).to receive(:make_query).with('nodes {}', 'path').and_return([])
      client.make_query('nodes {}', 'path', instance_name)
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
