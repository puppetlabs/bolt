# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'facts' do
  include PuppetlabsSpec::Fixtures

  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:hostname) { 'example' }
  let(:target) { Bolt::Target.new(hostname) }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should return an empty hash if no facts are set' do
    inventory.expects(:facts).with(target).returns({})
    is_expected.to run.with_params(target).and_return({})
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('facts')
    inventory.expects(:facts).returns({})

    is_expected.to run.with_params(target)
  end
end
