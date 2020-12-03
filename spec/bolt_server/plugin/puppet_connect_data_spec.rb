# frozen_string_literal: true

require 'bolt_server/plugin/puppet_connect_data'
require 'spec_helper'

describe BoltServer::Plugin::PuppetConnectData do
  let(:data) do
    { 'mykey' => { 'value' => 'somevalue' } }
  end

  subject { described_class.new(data) }
  context 'initializing the plugin' do
    it 'defines the correct plugin name' do
      expect(subject.name).to eq('puppet_connect_data')
    end

    it 'defines resolve_reference hooks' do
      expect(subject.hooks).to include(:resolve_reference, :validate_resolve_reference)
    end
  end

  context 'validating references' do
    it 'fails if no key is specified' do
      reference = { '_plugin' => 'puppet_connect_data' }
      expect { subject.validate_resolve_reference(reference) }.to raise_error(
        Bolt::ValidationError, /requires.*key/
      )
    end

    it 'fails if no value exists for the key' do
      reference = { '_plugin' => 'puppet_connect_data', 'key' => 'nosuchkey' }
      expect { subject.validate_resolve_reference(reference) }.to raise_error(
        Bolt::ValidationError, /tried to lookup key 'nosuchkey'/
      )
    end

    it 'succeeds if a value exists for the key' do
      reference = { '_plugin' => 'puppet_connect_data', 'key' => 'mykey' }
      expect { subject.validate_resolve_reference(reference) }.not_to raise_error
    end
  end

  context 'looking up data' do
    it 'returns the "value" field for the key' do
      reference = { '_plugin' => 'puppet_connect_data', 'key' => 'mykey' }
      expect(subject.resolve_reference(reference)).to eq('somevalue')
    end
  end
end
