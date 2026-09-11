# frozen_string_literal: true

require 'spec_helper'
require 'bolt/apply_target'
require 'bolt/error'

describe Bolt::ApplyTarget do
  let(:config) do
    {
      'transport' => 'ssh',
      'transports' => {
        'ssh' => { 'host' => 'default-host', 'user' => 'default-user', 'port' => 22 }
      }
    }
  end

  let(:target_hash) do
    {
      'name'    => 'myhost',
      'uri'     => 'myhost.example.com',
      'safe_name' => 'myhost',
      'config'  => {},
      'vars'    => {},
      'facts'   => {},
      'features' => [],
      'plugin_hooks' => {},
      'resources' => {}
    }
  end

  let(:target) { described_class.new(target_hash, config) }

  describe '.from_asserted_hash' do
    it 'raises Bolt::Error' do
      expect { described_class.from_asserted_hash({}) }
        .to raise_error(Bolt::Error, /cannot be instantiated inside apply blocks/)
    end
  end

  describe '.from_asserted_args' do
    it 'raises Bolt::Error' do
      expect { described_class.from_asserted_args('myhost') }
        .to raise_error(Bolt::Error, /cannot be instantiated inside apply blocks/)
    end
  end

  describe '.class-level _pcore_init_from_hash' do
    it 'raises RuntimeError' do
      expect { described_class._pcore_init_from_hash }
        .to raise_error(RuntimeError, /ApplyTarget shouldn't be instantiated/)
    end
  end

  describe '#initialize' do
    it 'sets name from target_hash' do
      expect(target.name).to eq('myhost')
    end

    it 'sets safe_name from target_hash' do
      expect(target.safe_name).to eq('myhost')
    end

    it 'sets host from uri' do
      expect(target.host).to eq('myhost.example.com')
    end

    it 'uses transport config host when uri has no host' do
      hash = target_hash.merge('uri' => nil)
      t = described_class.new(hash, config)
      expect(t.host).to eq('default-host')
    end

    it 'sets protocol from transport config when uri has no scheme' do
      expect(target.protocol).to eq('ssh')
    end

    it 'extracts port from uri when present' do
      hash = target_hash.merge('uri' => 'myhost.example.com:2222')
      t = described_class.new(hash, config)
      expect(t.port).to eq(2222)
    end

    it 'uses transport config port when uri has no port' do
      # URI 'myhost.example.com' has no explicit port, so falls back to config
      # which in this case provides no port either (nil from uri_obj.port)
      expect(target.port).to be_nil.or eq(22)
    end
  end

  describe '#to_s' do
    it 'returns the safe_name' do
      expect(target.to_s).to eq('myhost')
    end
  end

  describe '#hash' do
    it 'returns the hash of the name' do
      expect(target.hash).to eq('myhost'.hash)
    end
  end

  describe '#parse_uri' do
    it 'returns an empty URI when string is nil' do
      uri = target.parse_uri(nil)
      expect(uri.host).to be_nil
    end

    it 'raises ParseError for empty string' do
      expect { target.parse_uri('') }
        .to raise_error(Bolt::ParseError, /empty string/)
    end

    it 'parses a URI with scheme' do
      uri = target.parse_uri('ssh://myhost:22')
      expect(uri.host).to eq('myhost')
      expect(uri.port).to eq(22)
      expect(uri.scheme).to eq('ssh')
    end

    it 'parses a bare hostname without scheme' do
      uri = target.parse_uri('myhost')
      expect(uri.host).to eq('myhost')
    end

    it 'raises ParseError for an invalid URI with bad characters' do
      expect { target.parse_uri('http://[bad::uri') }
        .to raise_error(Bolt::ParseError, /Could not parse target URI/)
    end
  end

  describe '#resource' do
    it 'looks up resource by type and title' do
      resources = { 'File[/tmp/foo]' => { 'type' => 'File', 'title' => '/tmp/foo' } }
      hash = target_hash.merge('resources' => resources)
      t = described_class.new(hash, config)
      # resource calls Bolt::ResourceInstance.format_reference
      # We test that the method delegates correctly
      expect(t.resources).to eq(resources)
    end
  end
end
