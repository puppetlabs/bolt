# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt/inventory'
require 'bolt/plugin'
require 'yaml'

describe Bolt::Inventory do
  include BoltSpec::Config

  let(:pal)     { nil } # Not used
  let(:plugins) { Bolt::Plugin.setup(config, pal, Bolt::Analytics::NoopClient.new) }

  context 'with BOLT_INVENTORY set' do
    let(:inventory) { Bolt::Inventory.from_config(config, plugins) }
    let(:target)    { inventory.get_targets('target1')[0] }

    before(:each) do
      ENV['BOLT_INVENTORY'] = inventory_env.to_yaml
    end

    after(:each) { ENV.delete('BOLT_INVENTORY') }

    context 'with valid config' do
      let(:inventory_env) {
        {
          'targets' => ['target1'],
          'config' => {
            'transport' => 'winrm'
          }
        }
      }

      it 'should have the default protocol' do
        expect(target.protocol).to eq('winrm')
      end
    end

    context 'with invalid config' do
      let(:inventory_env) { 'I thought I could specify a file path here... ' }

      it 'should have the default protocol' do
        expect { inventory }.to raise_error(Bolt::ParseError, /Could not parse inventory from \$BOLT_INVENTORY/)
      end
    end
  end

  describe :create_version do
    it 'creates a version 2 inventory by default' do
      inv = Bolt::Inventory.create_version({}, config.transport, config.transports, plugins)
      expect(inv.class).to eq(Bolt::Inventory::Inventory)
    end

    it 'creates a version 2 inventory when specified' do
      inv = Bolt::Inventory.create_version({ 'version' => 2 }, config.transport, config.transports, plugins)
      expect(inv.class).to eq(Bolt::Inventory::Inventory)
    end

    it 'errors when invalid version number is specified' do
      expect { Bolt::Inventory.create_version({ 'version' => 1 }, config.transport, config.transports, plugins) }
        .to raise_error(Bolt::Inventory::ValidationError, /Unsupported version/)
    end
  end
end
