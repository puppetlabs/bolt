require 'spec_helper'
require 'bolt_ext/puppetdb_inventory'

describe "PuppetDBInventory" do
  describe Bolt::PuppetDBInventory::Client do
    let(:uri) { 'https://puppetdb:8081' }
    let(:cacert) { '/path/to/cacert' }
    let(:options) { {} }
    let(:client) { Bolt::PuppetDBInventory::Client.new(uri, cacert, options) }

    describe "#headers" do
      it 'sets content-type' do
        expect(client.headers['Content-Type']).to eq('application/json')
      end

      it 'includes the token if specified' do
        token = 'footokentest'
        options[:token] = token

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
  end

  describe Bolt::PuppetDBInventory::Config do
    let(:config_file) { nil }
    let(:config) { Bolt::PuppetDBInventory::Config.new(config_file, @options) }
    let(:options) do
      {
        'server_urls' => ['https://puppetdb:8081'],
        'cacert' => '/path/to/cacert',
        'token' => '/path/to/token',
        'cert' => '/path/to/cert',
        'key' => '/path/to/key'
      }
    end

    before :each do
      allow_any_instance_of(Bolt::PuppetDBInventory::Config).to receive(:load_config).and_return({})
      allow_any_instance_of(Bolt::PuppetDBInventory::Config).to receive(:validate_file_exists)
    end

    describe "#validate" do
      it "fails if no url is set" do
        options.delete('server_urls')

        expect { described_class.new(config_file, options) }.to raise_error(/server_urls must be specified/)
      end

      it "fails if no cacert is set" do
        options.delete('cacert')

        expect { described_class.new(config_file, options) }.to raise_error(/cacert must be specified/)
      end

      it "accepts only a token with cert/key" do
        options.delete('cert')
        options.delete('key')

        expect { described_class.new(config_file, options) }.not_to raise_error
      end

      it "accepts a cert and key without a token" do
        options.delete('token')

        expect { described_class.new(config_file, options) }.not_to raise_error
      end

      it "fails if only cert and no key is specified" do
        options.delete('key')

        expect { described_class.new(config_file, options) }.to raise_error(/cert and key must be specified together/)
      end

      it "fails if only key and no cert is specified" do
        options.delete('cert')

        expect { described_class.new(config_file, options) }.to raise_error(/cert and key must be specified together/)
      end
    end
  end
end
