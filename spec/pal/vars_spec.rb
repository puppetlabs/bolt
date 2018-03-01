require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt/pal'
require 'bolt/cli'
require 'bolt/inventory'

describe 'Vars function' do
  include BoltSpec::Files
  include BoltSpec::PAL

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:data) {
    {
      'nodes' => %w[example],
      'vars' => { 'pb' => 'jelly', 'mac' => 'cheese' }
    }
  }
  let(:inventory) { Bolt::Inventory.new(data) }
  let(:pal) { Bolt::PAL.new(config) }

  let(:target) { "$t = get_targets('example')[0]\n" }
  let(:vars) { "$t.vars\n" }
  let(:set_vars) { "$t.set_var('donuts', 'coffee')" }

  it 'should get vars on a target' do
    output = peval(target + vars, pal, nil, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese')
  end

  it 'should set vars on a target' do
    output = peval(target + set_vars + vars, pal, nil, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese', 'donuts' => 'coffee')
  end

  it 'should be consistent between target instances' do
    t2 = "$t2 = get_targets('example')[0]\n$t2.vars\n"
    output = peval(target + set_vars + t2, pal, nil, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese', 'donuts' => 'coffee')
  end

  it 'should be consistent when set on a separate instance' do
    t2 = "$t2 = get_targets('example')[0]"
    output = peval(target + t2 + set_vars + '$t2.vars', pal, nil, inventory)
    expect(output).to eq('pb' => 'jelly', 'mac' => 'cheese', 'donuts' => 'coffee')
  end

  it 'set_var should override data from inventory file' do
    set_pb = "$t.set_var('pb', 'jam')\n"
    output = peval(target + set_pb + vars, pal, nil, inventory)
    expect(output).to eq('pb' => 'jam', 'mac' => 'cheese')
  end

  it 'should not mutate previously assigned values' do
    set_pb = "$t.set_var('pb', 'jam')\n"
    assign1 = "$x = $t.vars['pb']\n"
    assign2 = "$y = $t.vars['pb']\n"
    print = "$x\n"
    output = peval(target + assign1 + set_pb + assign2 + print, pal, nil, inventory)
    expect(output).to eq('jelly')
  end
end
