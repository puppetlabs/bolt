# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/env_var'
require 'bolt/inventory'
require 'bolt/plugin'
require 'yaml'

describe Bolt::Inventory do
  include BoltSpec::Config
  include BoltSpec::EnvVar

  let(:pal)     { nil } # Not used
  let(:config)  { make_config }
  let(:plugins) { Bolt::Plugin.setup(config, pal) }

  context 'with BOLT_INVENTORY set' do
    let(:inventory) { Bolt::Inventory.from_config(config, plugins) }
    let(:target)    { inventory.get_targets('target1')[0] }

    around(:each) do |example|
      with_env_vars('BOLT_INVENTORY' => inventory_env.to_yaml) do
        example.run
      end
    end

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

  describe :from_config do
    let(:inventory) { Bolt::Inventory.from_config(config, plugins) }

    it 'sets inventory source to BOLT_INVENTORY' do
      data = { 'targets' => ['foo'] }.to_json

      with_env_vars('BOLT_INVENTORY' => data) do
        expect(inventory.source).to eq('BOLT_INVENTORY')
      end
    end

    it 'sets inventory source to configured inventory file' do
      expect(inventory.source).to eq(config.inventoryfile)
    end

    it 'sets inventory source to default inventory file' do
      allow(config).to receive(:inventoryfile).and_return(nil)
      allow(config.default_inventoryfile).to receive(:exist?).and_return(true)
      expect(inventory.source).to eq(config.default_inventoryfile)
    end

    it 'sets inventory source to nil when no inventory is loaded' do
      allow(config).to receive(:inventoryfile).and_return(nil)
      expect(inventory.source).to eq(nil)
    end
  end
end
