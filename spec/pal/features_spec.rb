# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/pal'
require 'bolt/pal'
require 'bolt/inventory/inventory'
require 'bolt/plugin'

describe 'set_features function' do
  include BoltSpec::PAL

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:executor)  { Bolt::Executor.new(1) }
  let(:pal)       { make_pal }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target)    { inventory.get_targets('example')[0] }

  it 'adds the feature to the target' do
    peval(<<-CODE, pal, executor, inventory)
    $t = get_targets('example')[0]
    $t.set_feature('shell')
    CODE
    expect(inventory.features(target).to_a).to eq(['shell'])
  end

  it 'only adds the feature once' do
    peval(<<-CODE, pal, executor, inventory)
    $t = get_targets('example')[0]
    $t.set_feature('shell').set_feature('shell')
    CODE
    expect(inventory.features(target).to_a).to eq(['shell'])
  end

  it 'deletes the feature if false is passed' do
    peval(<<-CODE, pal, executor, inventory)
    $t = get_targets('example')[0]
    $t.set_feature('shell')
    CODE

    expect(inventory.features(target).to_a).to eq(['shell'])

    peval(<<-CODE, pal, executor, inventory)
    $t = get_targets('example')[0]
    $t.set_feature('shell', false)
    CODE

    expect(inventory.features(target).to_a).to be_empty
  end

  it "does nothing if false is passed for a feature that isn't present" do
    peval(<<-CODE, pal, executor, inventory)
    $t = get_targets('example')[0]
    $t.set_feature('shell', false)
    CODE

    expect(inventory.features(target).to_a).to be_empty
  end

  it 'sets separate features for different nodes' do
    peval(<<-CODE, pal, executor, inventory)
    $targets = get_targets('example1,example2')
    $targets[0].set_feature('shell')
    $targets[1].set_feature('powershell')
    CODE

    example1, example2 = inventory.get_targets('example1,example2')
    expect(inventory.features(example1).to_a).to eq(['shell'])
    expect(inventory.features(example2).to_a).to eq(['powershell'])
  end
end
