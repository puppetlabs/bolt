# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/client'

describe Bolt::PuppetDB::Client do
  let(:uri) { 'https://puppetdb:8081' }
  let(:cacert) { File.expand_path('/path/to/cacert') }
  let(:config) { double('config', uri: URI.parse(uri), cacert: cacert, token: nil, cert: nil, key: nil) }
  let(:client) { Bolt::PuppetDB::Client.new(config) }

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

  describe "get facts for certnames" do
    let(:response) { double('response', code: 200, body: '{}') }
    let(:http_client) { double('http_client', post: response) }

    before :each do
      allow(client).to receive(:http_client).and_return(http_client)
    end

    it 'returns facts for certnames' do
      request = %w[foo bar foo]
      body = [{ 'certname' => 'foo', 'facts' => { 'a' => 1 } }, { 'certname' => 'bar', 'facts' => { 'b' => 2 } }]
      allow(response).to receive(:body).and_return(body.to_json)

      expect(client.facts_for_node(request)).to eq('foo' => { 'a' => 1 }, 'bar' => { 'b' => 2 })
    end

    it 'returns an empty list if no certnames are given' do
      expect(client.facts_for_node([])).to eq({})
    end
  end
end
