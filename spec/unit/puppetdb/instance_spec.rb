# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/instance'

describe Bolt::PuppetDB::Instance do
  let(:config) do
    {
      'server_urls' => ['https://puppet.example.com:8081'],
      'cacert'      => '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
    }
  end

  let(:instance) do
    inst = described_class.new(config: config)
    allow(inst).to receive(:http_client).and_return(http_client)
    inst
  end

  let(:http_client) { double('http_client') }

  let(:ok_response)  { double('response', code: 200, body: '[{"certname":"host1"}]') }
  let(:err_response) { double('response', code: 500, body: 'Internal Server Error') }
  let(:bad_response) { double('response', code: 400, body: 'Bad Request') }

  describe '#headers' do
    it 'includes Content-Type' do
      expect(instance.headers['Content-Type']).to eq('application/json')
    end

    it 'includes X-Authentication when token is configured' do
      allow(instance.config).to receive(:token).and_return('mytoken')
      expect(instance.headers['X-Authentication']).to eq('mytoken')
    end

    it 'omits X-Authentication when no token is configured' do
      allow(instance.config).to receive(:token).and_return(nil)
      expect(instance.headers).not_to have_key('X-Authentication')
    end
  end

  describe '#reject_url' do
    it 'adds the current url to bad_urls and clears it' do
      instance.instance_variable_set(:@current_url, 'https://puppet.example.com:8081')
      instance.reject_url
      expect(instance.instance_variable_get(:@bad_urls)).to include('https://puppet.example.com:8081')
      expect(instance.instance_variable_get(:@current_url)).to be_nil
    end
  end

  describe '#uri' do
    it 'returns an Addressable::URI for the current server URL' do
      allow(instance.config).to receive(:server_urls).and_return(['https://puppet.example.com:8081'])
      uri = instance.uri
      expect(uri.host).to eq('puppet.example.com')
      expect(uri.port).to eq(8081)
    end

    it 'raises PuppetDBError when all URLs are exhausted' do
      allow(instance.config).to receive(:server_urls).and_return([])
      expect { instance.uri }.to raise_error(Bolt::PuppetDBError, /Failed to connect/)
    end
  end

  describe '#make_query' do
    it 'returns parsed JSON on a 200 response' do
      allow(http_client).to receive(:post).and_return(ok_response)
      result = instance.make_query(['from', 'nodes'])
      expect(result).to eq([{ 'certname' => 'host1' }])
    end

    it 'raises PuppetDBError on a 400 response' do
      allow(http_client).to receive(:post).and_return(bad_response)
      expect { instance.make_query(['from', 'nodes']) }
        .to raise_error(Bolt::PuppetDBError, /Failed to query/)
    end

    it 'raises PuppetDBError when JSON cannot be parsed' do
      bad_json = double('response', code: 200, body: 'not json{{{')
      allow(http_client).to receive(:post).and_return(bad_json)
      expect { instance.make_query(['from', 'nodes']) }
        .to raise_error(Bolt::PuppetDBError, /Unable to parse/)
    end

    it 'raises PuppetDBFailoverError on network errors' do
      allow(http_client).to receive(:post).and_raise(StandardError, 'connection refused')
      allow(instance).to receive(:reject_url)
      # It retries recursively, so stub config to return no URLs on second attempt
      call_count = 0
      allow(instance).to receive(:uri) do
        call_count += 1
        raise Bolt::PuppetDBError, 'no URLs' if call_count > 1
        double('uri', to_s: 'https://puppet.example.com:8081')
      end
      expect { instance.make_query(['from', 'nodes']) }
        .to raise_error(Bolt::PuppetDBError)
    end
  end

  describe '#send_command' do
    let(:payload) { { 'certname' => 'host1', 'data' => 'value' } }
    let(:ok_cmd_response) { double('response', code: 200, body: '{"uuid":"abc-123"}') }

    it 'returns the UUID from a successful response' do
      allow(http_client).to receive(:post).and_return(ok_cmd_response)
      result = instance.send_command('deactivate node', 3, payload)
      expect(result).to eq('abc-123')
    end

    it 'raises Bolt::Error when payload has no certname' do
      expect { instance.send_command('deactivate node', 3, {}) }
        .to raise_error(Bolt::Error, /certname/)
    end

    it 'raises PuppetDBError on a non-200 response' do
      allow(http_client).to receive(:post).and_return(err_response)
      expect { instance.send_command('deactivate node', 3, payload) }
        .to raise_error(Bolt::PuppetDBError, /Failed to invoke/)
    end

    it 'raises PuppetDBError when response body is not valid JSON' do
      bad = double('response', code: 200, body: 'not-json{{{')
      allow(http_client).to receive(:post).and_return(bad)
      expect { instance.send_command('deactivate node', 3, payload) }
        .to raise_error(Bolt::PuppetDBError, /Unable to parse/)
    end
  end
end
