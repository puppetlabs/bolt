# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'set_feature' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:target) { Bolt::Target.new('example') }
  let(:tasks_enabled) { true }
  let(:feature) { 'feature' }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should set a variable on a target' do
    inventory.expects(:set_feature).with(target, feature, true).returns(target)
    is_expected.to run.with_params(target, feature, true).and_return(target)
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target, 1, 'one')
                      .and_raise_error(ArgumentError,
                                       "'set_feature' parameter 'feature' expects a String value, got Integer")
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('set_feature')
    inventory.expects(:set_feature).with(target, feature, true).returns(target)

    is_expected.to run.with_params(target, feature, true).and_return(target)
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that set_feature is not available' do
      is_expected.to run
        .with_params(target, feature, true).and_raise_error(/Plan language function 'set_feature' cannot be used/)
    end
  end
end
