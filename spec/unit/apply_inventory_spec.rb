# frozen_string_literal: true

require 'spec_helper'
require 'bolt/apply_inventory'

describe Bolt::ApplyInventory do
  let(:config_hash) { {} }
  let(:inventory) { described_class.new(config_hash) }

  describe '#initialize' do
    it 'sets config_hash' do
      inv = described_class.new('key' => 'val')
      expect(inv.config_hash).to eq('key' => 'val')
    end

    it 'defaults config_hash to empty hash' do
      expect(inventory.config_hash).to eq({})
    end
  end

  describe '#version' do
    it 'returns 2' do
      expect(inventory.version).to eq(2)
    end
  end

  describe '#target_implementation_class' do
    it 'returns Bolt::ApplyTarget' do
      expect(inventory.target_implementation_class).to eq(Bolt::ApplyTarget)
    end
  end

  describe '#create_apply_target and accessors' do
    let(:target) { double('target', name: 'myhost', vars: { 'x' => 1 }, facts: { 'os' => 'linux' }, features: ['shell'], plugin_hooks: {}, config: {}) }

    before(:each) { inventory.create_apply_target(target) }

    describe '#vars' do
      it 'returns vars for a registered target' do
        expect(inventory.vars(target)).to eq('x' => 1)
      end
    end

    describe '#facts' do
      it 'returns facts for a registered target' do
        expect(inventory.facts(target)).to eq('os' => 'linux')
      end
    end

    describe '#features' do
      it 'returns features for a registered target' do
        expect(inventory.features(target)).to eq(['shell'])
      end
    end

    describe '#plugin_hooks' do
      it 'returns plugin_hooks for a registered target' do
        expect(inventory.plugin_hooks(target)).to eq({})
      end
    end

    describe '#target_config' do
      it 'returns config for a registered target' do
        expect(inventory.target_config(target)).to eq({})
      end
    end

    describe '#resource' do
      it 'calls resource on the registered target' do
        expect(target).to receive(:resource).with('File', '/tmp/foo').and_return('resource_data')
        expect(inventory.resource(target, 'File', '/tmp/foo')).to eq('resource_data')
      end
    end
  end

  describe 'InvalidFunctionCall methods' do
    it '#get_targets raises InvalidFunctionCall' do
      expect { inventory.get_targets('all') }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /get_targets/)
    end

    it '#get_target raises InvalidFunctionCall' do
      expect { inventory.get_target('host') }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /get_target/)
    end

    it '#set_var raises InvalidFunctionCall' do
      expect { inventory.set_var(nil, 'k', 'v') }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /set_var/)
    end

    it '#set_feature raises InvalidFunctionCall' do
      expect { inventory.set_feature(nil, 'shell') }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /set_feature/)
    end

    it '#add_facts raises InvalidFunctionCall' do
      expect { inventory.add_facts(nil, {}) }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /add_facts/)
    end

    it '#add_to_group raises InvalidFunctionCall' do
      expect { inventory.add_to_group(nil, 'mygroup') }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /add_to_group/)
    end

    it '#set_config raises InvalidFunctionCall' do
      expect { inventory.set_config(nil, 'key', 'val') }
        .to raise_error(Bolt::ApplyInventory::InvalidFunctionCall, /set_config/)
    end
  end

  describe 'InvalidFunctionCall error' do
    it 'has correct kind' do
      err = Bolt::ApplyInventory::InvalidFunctionCall.new('get_targets')
      expect(err.kind).to eq('bolt.inventory/invalid-function-call')
    end

    it 'includes the function name in the message' do
      err = Bolt::ApplyInventory::InvalidFunctionCall.new('my_function')
      expect(err.message).to match(/my_function/)
    end
  end
end
