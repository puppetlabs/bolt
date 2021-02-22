# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/client'
require 'bolt_spec/puppetdb'
require 'bolt_spec/bolt_server'
require 'httpclient'

describe Bolt::PuppetDB::Client do
  let(:uri) { 'https://puppetdb:8081' }
  let(:cacert) { File.expand_path('/path/to/cacert') }
  let(:client) { Bolt::PuppetDB::Client.new(config) }
  let(:connect_timeout) { 45 }
  let(:read_timeout) { 45 }

  let(:config) do
    double(
      'config',
      server_urls: [uri],
      cacert: cacert,
      token: nil,
      cert: nil,
      key: nil,
      connect_timeout: nil,
      read_timeout: nil
    )
  end

  describe "#http_client" do
    let(:http_client) { double('httpclient', ssl_config: ssl_config) }
    let(:ssl_config)  { double('ssl_config', set_client_cert_file: nil, add_trust_ca: nil) }

    before(:each) do
      allow(HTTPClient).to receive(:new).and_return(http_client)
    end

    it 'sets connect_timeout when connect_timeout is set' do
      allow(config).to receive(:connect_timeout).and_return(connect_timeout)
      expect(http_client).to receive(:connect_timeout=).with(connect_timeout)
      client.http_client
    end

    it 'does not connect_timeout when connect_timeout is not set' do
      expect(http_client).not_to receive(:connect_timeout=)
      client.http_client
    end

    it 'sets receive_timeout when read_timeout is set' do
      allow(config).to receive(:read_timeout).and_return(read_timeout)
      expect(http_client).to receive(:receive_timeout=).with(read_timeout)
      client.http_client
    end

    it 'does not set receive_timeout when read_timeout is not set' do
      expect(http_client).not_to receive(:receive_timeout=)
      client.http_client
    end
  end

  describe "#headers" do
    it 'sets content-type' do
      expect(client.headers['Content-Type']).to eq('application/json')
    end

    it 'includes the token if specified' do
      token = 'footokentest'
      allow(config).to receive(:token).and_return(token)

      expect(client.headers['X-Authentication']).to eq(token)
    end

    it 'omits token if not specified' do
      expect(client.headers).not_to include('X-Authentication')
    end
  end

  describe "#query_certnames" do
    let(:response) { double('response', code: 200, body: '[]') }
    let(:http_client) { double('http_client', post: response) }

    before :each do
      allow(client).to receive(:http_client).and_return(http_client)
    end

    it 'returns unique certnames' do
      body = [{ 'certname' => 'foo' }, { 'certname' => 'bar' }, { 'certname' => 'foo' }]
      allow(response).to receive(:body).and_return(body.to_json)

      expect(client.query_certnames('query')).to eq(%w[foo bar])
    end

    it 'returns an empty list if the query result is empty' do
      expect(client.query_certnames('query')).to eq([])
    end

    it 'fails if the result has no certname field' do
      body = [{ 'environment' => 'production' }, { 'environment' => 'development' }]
      allow(response).to receive(:body).and_return(body.to_json)

      expect { client.query_certnames('query') }.to raise_error(/Query results did not contain a 'certname' field/)
    end

    it 'fails if the response from PuppetDB is an error' do
      allow(response).to receive(:code).and_return(400)
      allow(response).to receive(:body).and_return("something went wrong")

      expect { client.query_certnames('query') }.to raise_error(/Failed to query PuppetDB: something went wrong/)
    end
  end

  describe "#facts_for_node" do
    it 'should not make a request to pdb if there are no nodes' do
      expect(client).to receive(:http_client).never
      facts = client.facts_for_node([])
      expect(facts).to eq({})
    end
  end

  context 'when connected to puppetdb', puppetdb: true do
    include BoltSpec::PuppetDB
    include BoltSpec::BoltServer

    def facts_hash
      { 'node1' => {
        'foo' => 'bar',
        'name' => 'node1'
      },
        'node2' => {
          'foo' => 'bar',
          '1' => 'the loneliest number',
          'name' => {
            'node' => {
              'kit' => 'kat'
            }
          }
        } }
    end

    let(:client) { pdb_client }

    # Hash formatting is hard, so do it in the examples
    let(:expected_node1_foo) do
      [{ "certname" => "node1", "path" => ["foo"], "value" => "bar" }]
    end

    let(:expected_node2_foo) do
      [{ "certname" => "node2", "path" => ["foo"], "value" => "bar" }]
    end

    let(:expected_node2_all) do
      [{ "certname" => "node2",
         "path" => ["foo"],
         "value" => "bar" },
       { "certname" => "node2",
         "path" => %w[name node kit],
         "value" => "kat" }]
    end

    before(:all) do
      wait_until_available(timeout: 30, interval: 1)
      sleep(120)
      push_facts(facts_hash)
    end

    after(:all) do
      clear_facts(facts_hash)
    end

    it 'should get facts' do
      facts = client.facts_for_node(%w[node1 node2])
      expect(facts).to eq(facts_hash)
    end

    it 'should get fact values' do
      values = client.fact_values(%w[node1], [['foo']])
      expect(values).to eq('node1' => expected_node1_foo)
    end

    it 'should get fact values for multiple nodes' do
      values = client.fact_values(%w[node1 node2], [['foo']])
      expect(values).to eq('node1' => expected_node1_foo,
                           'node2' => expected_node2_foo)
    end

    it 'should get fact values for multiple facts' do
      values = client.fact_values(%w[node1 node2], [['foo'], %w[name node kit]])
      expect(values).to eq('node1' => expected_node1_foo,
                           'node2' => expected_node2_all)
    end

    it 'should get certnames' do
      certnames = client.query_certnames("inventory { facts.name.node.kit = 'kat' }")
      expect(certnames).to eq(['node2'])
    end

    context 'without a port set' do
      it 'should set the port to 8081 if no port is specified' do
        conf = pdb_conf
        conf['server_urls'] = ['https://puppetdb']
        client = Bolt::PuppetDB::Client.new(Bolt::PuppetDB::Config.new(conf))
        expect(client.uri.to_s).to eq('https://puppetdb:8081')
      end
    end

    it 'should error with an invalid query' do
      expect { client.query_certnames("inventory { 'name' = 'node2' }") }.to raise_error(Bolt::PuppetDBError, /parse/)
    end

    it 'should fail after all servers fail' do
      conf = pdb_conf
      conf['server_urls'] = ['https://bad1.example.com', 'https://bad2.example.com']
      client = Bolt::PuppetDB::Client.new(Bolt::PuppetDB::Config.new(conf))
      msg = "Failed to connect to all PuppetDB server_urls: https://bad1.example.com, https://bad2.example.com."
      expect { client.facts_for_node(%w[node1 node2]) }.to raise_error(Bolt::PuppetDBError, msg)
    end

    it 'should failover if the first server fails' do
      conf = pdb_conf
      conf['server_urls'] = ['https://bad.example.com', pdb_conf['server_urls']]
      client = Bolt::PuppetDB::Client.new(Bolt::PuppetDB::Config.new(conf))
      facts = client.facts_for_node(%w[node1 node2])
      expect(facts).to eq(facts_hash)
    end
  end

  describe "#fact_values" do
    it 'should not make a request to pdb if there are no nodes' do
      expect(client).to receive(:http_client).never
      facts = client.fact_values([])
      expect(facts).to eq({})
    end
  end
end
