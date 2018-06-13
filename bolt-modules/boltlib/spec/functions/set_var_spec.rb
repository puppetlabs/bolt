# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'set_var' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:target) { Bolt::Target.new('example') }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should set a variable on a target' do
    inventory.expects(:set_var).with(target, 'a', 'b').returns(nil)
    is_expected.to run.with_params(target, 'a', 'b').and_return(nil)
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target, 1, 'one')
                      .and_raise_error(ArgumentError,
                                       "'set_var' parameter 'key' expects a String value, got Integer")
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('set_var')
    inventory.expects(:set_var).with(target, 'a', 'b').returns(nil)

    is_expected.to run.with_params(target, 'a', 'b').and_return(nil)
  end
end
