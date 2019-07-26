# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt/pal'
require 'bolt/inventory'

describe 'Facts functions' do
  include BoltSpec::Files
  include BoltSpec::PAL

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:node) { 'example' }
  let(:node2) { 'localhost' }
  let(:data) {
    {
      'nodes' => [node, node2],
      'facts' => { 'hot' => 'chocolate' }
    }
  }
  let(:inv) { Bolt::Inventory.new(data) }
  let(:pal) { Bolt::PAL.new(modulepath, nil, nil) }

  let(:analytics) { Bolt::Analytics::NoopClient.new }
  let(:executor) { Bolt::Executor.new(1, analytics) }

  let(:target) { "$t = get_targets(#{node})[0]\n" }
  let(:facts) { "facts($t)\n" }
  let(:add_facts) { "add_facts($t, {'hot' => 'tamales', 'dark' => 'chocolate'})\n" }

  it 'should get facts for a target' do
    output = peval(target + facts, pal, nil, inv)
    expect(output).to eq('hot' => 'chocolate')
  end

  it 'should set facts for a target' do
    output = peval(target + add_facts + facts, pal, executor, inv)
    expect(output).to eq('hot' => 'tamales', 'dark' => 'chocolate')
  end

  it 'should be consistent between target instances' do
    t2 = "$t2 = get_targets(#{node})[0]\nfacts($t2)\n"
    output = peval(target + add_facts + t2 + facts, pal, executor, inv)
    expect(output).to eq('hot' => 'tamales', 'dark' => 'chocolate')
  end

  it 'should set facts on all nodes in the group' do
    t2 = "$t2 = get_targets(#{node2})[0]\nfacts($t2)"
    output = peval(t2, pal, nil, inv)
    expect(output).to eq('hot' => 'chocolate')
  end

  it 'should be consistent when modified on a separate instance' do
    t2 = "$t2 = get_targets(#{node})[0]\n"
    output = peval(target + t2 + add_facts + "facts($t2)", pal, executor, inv)
    expect(output).to eq('hot' => 'tamales', 'dark' => 'chocolate')
  end

  it 'should not mutate previously assigned facts' do
    assignx = "$x = facts($t)\n"
    output = peval(target + assignx + add_facts + "$x", pal, executor, inv)
    expect(output).to eq('hot' => 'chocolate')
  end
end
