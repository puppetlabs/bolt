# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/inventory/target'

describe Bolt::Inventory::Target do
  let(:inventory)   { Bolt::Inventory.empty }
  let(:target)      { described_class.new(target_data, inventory) }
  let(:target_data) { { 'name' => 'target' } }

  context '#initialize' do
    it 'warns when target has dotted facts' do
      target_data['facts'] = {
        'bing.bang' => 'bong',
        'sing.sang' => 'song',
        'ding.dang' => 'dong'
      }

      target

      expect(@log_output.readlines).to include(
        /WARN.*Target 'target' includes dotted fact names: 'bing.bang', 'sing.sang', 'ding.dang'/
      )
    end

    it 'warns when target group has dotted facts' do
      allow(inventory).to receive(:group_data_for).and_return(
        'facts' => {
          'bing.bang' => 'bong',
          'sing.sang' => 'song',
          'ding.dang' => 'dong'
        }
      )

      target

      expect(@log_output.readlines).to include(
        /WARN.*Target 'target' includes dotted fact names: 'bing.bang', 'sing.sang', 'ding.dang'/
      )
    end
  end

  context '#add_facts' do
    it 'warns when adding dotted facts' do
      target.add_facts(
        'bing.bang' => 'bong',
        'sing.sang' => 'song',
        'ding.dang' => 'dong'
      )

      expect(@log_output.readlines).to include(
        /WARN.*Target 'target' includes dotted fact names: 'bing.bang', 'sing.sang', 'ding.dang'/
      )
    end
  end

  context 'validating target name' do
    ['foo bar', 'foo,bar'].each do |name|
      it "rejects #{name}" do
        expect { described_class.new({ 'name' => name }, inventory) }.to raise_error(/Illegal character/)
      end
    end
  end
end
