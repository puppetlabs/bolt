# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/azure'

describe Bolt::Plugin::Azure do
  let(:config) do
    {
      'tenant_id' => 'HrGSPVAbDeRBIiGlDNVQkw3FMds10GlU',
      'client_id' => 'HrGSPVAbDeRBIiGlDNVQkw3FMds10GlU',
      'client_secret' => 'HrGSPVAbDeRBIiGlDNVQkw3FMds10GlU',
      'subscription_id' => 'HrGSPVAbDeRBIiGlDNVQkw3FMds10GlU'
    }
  end

  let(:options) do
    {
      '_plugin' => 'azure',
      'resource_group' => 'puppet',
      'scale_set' => 'bolt',
      'location' => 'eastus',
      'tags' => {
        'foo' => 'bar',
        'baz' => 'bak'
      }
    }
  end

  let(:plugin) { Bolt::Plugin::Azure.new(config) }

  it 'has a hook for inventory_targets' do
    expect(plugin.hooks).to eq(['inventory_targets'])
  end

  context 'when validating keys' do
    it 'errors with unexpected config keys' do
      config['foo'] = 'bar'
      expect { plugin }.to raise_error(Bolt::ValidationError, /foo/)
    end

    it 'errors with unexpected inventory config keys' do
      options['foo'] = 'bar'
      expect { plugin.validate_options(options) }.to raise_error(Bolt::ValidationError, /foo/)
    end
  end

  context 'when validating credentials' do
    it 'errors when a credential is missing' do
      config.delete('tenant_id')
      expect { plugin.credentials(options) }.to raise_error(Bolt::ValidationError, /tenant_id/)
    end

    it 'prefers credentials set in the inventory' do
      options['tenant_id'] = 'foo'
      expect(plugin.credentials(options)).to include('tenant_id' => 'foo')
    end
  end
end
