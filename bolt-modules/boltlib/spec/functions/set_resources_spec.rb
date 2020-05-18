# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'set_resources' do
  let(:executor)      { Bolt::Executor.new }
  let(:inventory)     { Bolt::Inventory.empty }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  let(:target)    { inventory.get_target('foo') }
  let(:target2)   { inventory.get_target('bar') }
  let(:resource)  { Bolt::ResourceInstance.new(resource_data) }
  let(:resource2) { Bolt::ResourceInstance.new(resource2_data) }

  let(:resource_data) do
    {
      'target' => target,
      'type'   => 'File',
      'title'  => '/etc/puppetlabs',
      'state'  => { 'ensure' => 'present' }
    }
  end

  let(:resource2_data) do
    {
      'target' => target2,
      'type'   => 'Package',
      'title'  => 'mysql',
      'state'  => { 'ensure' => 'installed' }
    }
  end

  it 'sets a single resource data hash' do
    is_expected.to run.with_params(target, resource_data).and_return([resource])
  end

  it 'sets multiple resource data hashes' do
    resource2_data['target'] = target
    is_expected.to run.with_params(target, [resource_data, resource2_data])
                      .and_return([resource, resource2])
  end

  it 'sets a single ResourceInstance' do
    is_expected.to run.with_params(target, resource).and_return([resource])
  end

  it 'sets multiple ResourceInstances' do
    resource2_data['target'] = target
    is_expected.to run.with_params(target, [resource, resource2])
                      .and_return([resource, resource2])
  end

  it 'sets multiple resource data hashes and ResourceInstances' do
    resource2_data['target'] = target
    is_expected.to run.with_params(target, [resource, resource2_data])
                      .and_return([resource, resource2])
  end

  it 'errors on unknown types' do
    is_expected.to run.with_params(mock('anything')).and_raise_error(ArgumentError)
  end

  it 'errors when setting a resource for one target on another' do
    is_expected.to run.with_params(target, resource2).and_raise_error(Bolt::ValidationError)
  end

  it 'calls Target#set_resource' do
    target.expects(:set_resource).with(resource).returns(resource)
    is_expected.to run.with_params(target, resource).and_return([resource])
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('set_resources')
    is_expected.to run.with_params(target, resource).and_return([resource])
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that set_resources is not available' do
      is_expected.to run.with_params(target, resource)
                        .and_raise_error(/Plan language function 'set_resources' cannot be used/)
    end
  end
end
