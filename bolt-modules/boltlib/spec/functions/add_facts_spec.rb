# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'add_facts' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('example') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should set a fact on a target' do
    data = { 'a' => 'b', 'c' => 'd' }
    is_expected.to run.with_params(target, data).and_return(target)
    expect(target.facts).to eq(data)
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target, 1)
                      .and_raise_error(ArgumentError,
                                       "'add_facts' parameter 'facts' expects a Hash value, got Integer")
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('add_facts')
    is_expected.to run.with_params(target, {})
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that add_facts is not available' do
      is_expected.to run.with_params(target, {})
                        .and_raise_error(/Plan language function 'add_facts' cannot be used/)
    end
  end
end
