# frozen_string_literal: true

require 'spec_helper'
require 'bolt/resource_instance'
require 'bolt/target'
require 'bolt/inventory'
require 'bolt/plugin'
require 'bolt/config'

describe Bolt::ResourceInstance do
  let(:target)  { Bolt::Target.new('target1') }
  let(:target2) { Bolt::Target.new('target2') }

  let(:resource) do
    Bolt::ResourceInstance.new(resource_data)
  end

  let(:resource2) do
    Bolt::ResourceInstance.new(resource2_data)
  end

  let(:resource_data) do
    {
      'target'        => target,
      'type'          => 'File',
      'title'         => '/etc/puppetlabs/',
      'state'         => { 'ensure' => 'present' },
      'desired_state' => { 'ensure' => 'absent' },
      'events'        => [{ 'audited' => false }]
    }
  end

  let(:resource2_data) do
    {
      'target'        => target2,
      'type'          => 'File',
      'title'         => '/etc/ssh/',
      'state'         => { 'ensure' => 'present' },
      'desired_state' => { 'ensure' => 'absent' },
      'events'        => [{ 'audited' => false }]
    }
  end

  context '#eql?' do
    it 'returns true if the resources match' do
      expect(resource.eql?(resource)).to eq(true)
    end

    it 'returns false if the resources do not match' do
      expect(resource.eql?(resource2)).to eq(false)
    end
  end

  context '#reference' do
    it 'returns the resource reference' do
      expect(resource.reference).to eq('File[/etc/puppetlabs/]')
    end
  end

  context '#to_s' do
    it 'returns the resource reference' do
      expect(resource.to_s).to eq(resource.reference)
    end
  end

  context '#to_hash' do
    it 'returns the resource data' do
      expect(resource.to_hash).to eq(resource_data)
    end
  end

  context '#set_state' do
    it 'shallow merges with existing state' do
      resource_data['state'] = {
        'ensure' => 'present',
        'source' => '/etc/puppetlabs/bolt/bolt-defaults.yaml',
        'foo'    => { 'bar' => true }
      }

      resource.set_state(
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml',
        'foo'    => { 'baz' => false }
      )

      expect(resource.state).to eq(
        'ensure' => 'present',
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml',
        'foo'    => { 'baz' => false }
      )
    end

    it 'errors when state is not a Hash' do
      expect { resource.set_state('present') }.to raise_error(Bolt::ValidationError)
    end
  end

  context '#overwrite_state' do
    it 'overwrites existing state' do
      resource.overwrite_state(
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml'
      )

      expect(resource.state).to eq(
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml'
      )
    end

    it 'errors when state is not a Hash' do
      expect { resource.overwrite_state('present') }.to raise_error(Bolt::ValidationError)
    end
  end

  context '#set_desired_state' do
    it 'shallow merges with existing desired state' do
      resource_data['desired_state'] = {
        'ensure' => 'present',
        'source' => '/etc/puppetlabs/bolt/bolt-defaults.yaml',
        'foo'    => { 'bar' => true }
      }

      resource.set_desired_state(
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml',
        'foo'    => { 'baz' => false }
      )

      expect(resource.desired_state).to eq(
        'ensure' => 'present',
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml',
        'foo'    => { 'baz' => false }
      )
    end

    it 'errors when desired state is not a Hash' do
      expect { resource.set_desired_state('present') }.to raise_error(Bolt::ValidationError)
    end
  end

  context '#overwrite_desired_state' do
    it 'overwrites existing desired state' do
      resource.overwrite_desired_state(
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml'
      )

      expect(resource.desired_state).to eq(
        'source' => '/Users/.puppetlabs/etc/bolt/bolt-defaults.yaml'
      )
    end

    it 'errors when desired state is not a Hash' do
      expect { resource.overwrite_desired_state('present') }.to raise_error(Bolt::ValidationError)
    end
  end

  context '#[]' do
    it 'returns an attribute from state' do
      expect(resource['ensure']).to eq('present')
    end

    it 'returns nil for a missing attribute' do
      expect(resource['foo']).to eq(nil)
    end
  end

  context '.from_asserted_hash' do
    it 'creates a ResourceInstance from a data hash' do
      r = described_class.from_asserted_hash(resource_data)
      expect(r).to be_a(described_class)
      expect(r.type).to eq('File')
    end
  end

  context '.from_asserted_args' do
    it 'creates a ResourceInstance from positional arguments' do
      r = described_class.from_asserted_args(target, 'Package', 'vim')
      expect(r).to be_a(described_class)
      expect(r.type).to eq('Package')
      expect(r.title).to eq('vim')
    end

    it 'accepts optional state and events' do
      r = described_class.from_asserted_args(target, 'Service', 'ssh',
                                             { 'ensure' => 'running' }, nil, [])
      expect(r.state).to eq('ensure' => 'running')
    end
  end

  context '._pcore_type' do
    it 'returns the pcore type for ResourceInstance' do
      expect(described_class._pcore_type).not_to be_nil
    end
  end

  context '.class._pcore_init_from_hash' do
    it 'raises an error' do
      expect { described_class._pcore_init_from_hash({}) }
        .to raise_error(RuntimeError, /ResourceInstance shouldn't be instantiated/)
    end
  end

  context '#_pcore_init_from_hash' do
    it 'reinitializes from a hash' do
      r = described_class.new(resource_data)
      r._pcore_init_from_hash(resource_data)
      expect(r.type).to eq('File')
    end
  end

  context '#to_json' do
    it 'returns a JSON string' do
      allow(target).to receive(:to_json).and_return('"target1"')
      json = resource.to_json
      parsed = JSON.parse(json)
      expect(parsed['type']).to eq('File')
    end
  end

  context '#add_event' do
    it 'appends an event to the events list' do
      initial_count = resource.events.length
      resource.add_event({ 'message' => 'new event' })
      expect(resource.events.length).to eq(initial_count + 1)
    end
  end
end
