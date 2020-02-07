# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'vars' do
  include PuppetlabsSpec::Fixtures

  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:hostname) { 'example' }
  let(:target) { Bolt::Target.new(hostname) }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      inventory.stubs(:version).returns(2)
      inventory.stubs(:target_implementation_class).returns(Bolt::Target)
      example.run
    end
  end

  it 'should return an empty hash if no vars are set' do
    inventory.expects(:vars).with(target).returns({})
    is_expected.to run.with_params(target).and_return({})
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('vars')
    inventory.expects(:vars).with(target).returns({})

    is_expected.to run.with_params(target).and_return({})
  end
end
