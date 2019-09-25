# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/vault'

describe Bolt::Plugin::Vault do
  let(:server_url) { 'http://127.0.0.1:8200' }
  let(:path) { 'foo/bar' }
  let(:field) { 'foo' }
  let(:secret) { 'bar' }

  let(:config) do
    {
      'server_url' => server_url,
      'auth' => {
        'method' => 'token',
        'token' => 'secret'
      }
    }
  end

  let(:options) do
    {
      '_plugin' => 'vault',
      'path' => path,
      'field' => field
    }
  end

  let(:response) do
    {
      'data' => {
        'foo' => secret
      }
    }
  end

  let(:plugin) { Bolt::Plugin::Vault.new(config: config) }

  it 'errors when missing cacert and using https' do
    config['server_url'] = 'https://127.0.0.1:8200'
    uri = plugin.uri(options)
    expect { plugin.client(uri, options) }.to raise_error(Bolt::ValidationError, /https/)
  end

  context 'when validating keys' do
    it 'errors with invalid config keys' do
      config['foo'] = 'bar'
      expect { plugin }.to raise_error(Bolt::ValidationError, /foo/)
    end

    it 'errors with invalid inventory config keys' do
      options['foo'] = 'bar'
      expect { plugin.validate_options(options) }.to raise_error(Bolt::ValidationError, /foo/)
    end

    it 'errors when missing required inventory config key' do
      options.delete('path')
      expect { plugin.validate_options(options) }.to raise_error(Bolt::ValidationError, /path/)
    end

    it 'errors when missing required auth method key' do
      auth = config['auth'].delete('token')
      keys = %w[token]
      expect { plugin.validate_auth(auth, keys) }.to raise_error(Bolt::ValidationError, /token/)
    end

    it 'errors when using unknown auth method' do
      auth = config['auth']
      auth['method'] = 'foo'
      expect { plugin.request_token(auth, options) }.to raise_error(
        Bolt::ValidationError, /foo/
      )
    end
  end

  context 'when building the uri' do
    it 'builds the correct v1 uri' do
      expect(plugin.uri(options).to_s).to eq("#{server_url}/v1/#{path}")
    end

    it 'builds the correct v2 uri' do
      path_v2 = path.split('/').insert(1, 'data').join('/')
      options['version'] = 2
      expect(plugin.uri(options).to_s).to eq("#{server_url}/v1/#{path_v2}")
    end

    it 'prefers keys from inventory config' do
      server_url = 'http://127.0.0.1:9000'
      options['server_url'] = server_url
      expect(plugin.uri(options).to_s).to eq("#{server_url}/v1/#{path}")
    end

    it 'prefers a path from an auth method' do
      path = 'cat/dog'
      expect(plugin.uri(options, path).to_s).to eq("#{server_url}/v1/#{path}")
    end
  end

  context 'when parsing the response' do
    it 'errors when response is missing field from inventory config' do
      options['field'] = 'baz'
      expect { plugin.parse_response(response, options) }.to raise_error(
        Bolt::ValidationError, /baz/
      )
    end

    it 'accesses v2 data' do
      response_v2 = { 'data' => response }
      options['version'] = 2
      expect(plugin.parse_response(response_v2, options)).to eq(secret)
    end

    it 'returns the value of a field from the inventory config' do
      expect(plugin.parse_response(response, options)).to eq(secret)
    end

    it 'returns a hash of data when no field is given' do
      options.delete('field')
      expect(plugin.parse_response(response, options)).to eq(response['data'])
    end
  end
end
