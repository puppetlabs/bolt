# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt_spec/config'
require 'bolt/pal'
require 'bolt/inventory/inventory'
require 'bolt/plugin'

describe 'Vars function' do
  include BoltSpec::Files
  include BoltSpec::PAL
  include BoltSpec::Config

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:data) {
    {
      'targets' => %w[example],
      'vars' => { 'pb' => 'jelly', 'mac' => 'cheese' }
    }
  }

  let(:inventory) { Bolt::Inventory::Inventory.new(data, config.transport, config.transports, plugins) }
  let(:pal)       { Bolt::PAL.new(modulepath, nil, nil) }
  let(:plugins)   { Bolt::Plugin.setup(config, nil, analytics) }

  let(:analytics) { Bolt::Analytics::NoopClient.new }
  let(:executor)  { Bolt::Executor.new(1, analytics) }

  let(:target)     { "$t = get_targets('example')[0]\n" }
  let(:vars)       { "$t.vars\n" }
  let(:set_donuts) { "$t.set_var('donuts', 'coffee')\n" }
  let(:set_pb)     { "$t.set_var('pb', 'banana')\n" }

  it 'should get vars on a target' do
    output = peval(target + vars, pal, executor, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese')
  end

  it 'should set vars on a target' do
    output = peval(target + set_donuts + vars, pal, executor, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese', 'donuts' => 'coffee')
  end

  it 'should be consistent between target instances' do
    t2 = "$t2 = get_targets('example')[0]\n$t2.vars\n"
    output = peval(target + set_pb + set_donuts + t2, pal, executor, inventory)
    expect(output).to eq('pb' => 'banana', 'mac' => 'cheese', 'donuts' => 'coffee')
  end

  it 'should be consistent when modified on a separate instance' do
    t2 = "$t2 = get_targets('example')[0]"
    output = peval(target + t2 + set_donuts + '$t2.vars', pal, executor, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese', 'donuts' => 'coffee')
  end

  it 'set_var should override data from inventory file' do
    set_pb = "$t.set_var('pb', 'jam')\n"
    output = peval(target + set_pb + vars, pal, executor, inventory)
    expect(output).to eq('pb' => 'jam', 'mac' => 'cheese')
  end

  it 'should not mutate previously assigned values' do
    set_pb = "$t.set_var('pb', 'jam')\n"
    assign1 = "$x = $t.vars['pb']\n"
    output = peval(target + assign1 + set_pb + "$x", pal, executor, inventory)
    expect(output).to eq('jelly')
  end
end
