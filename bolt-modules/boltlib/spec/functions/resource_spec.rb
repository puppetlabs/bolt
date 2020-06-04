# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'resource' do
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:hostname) { 'example' }
  let(:target) { inventory.get_target(hostname) }
  let(:hash) { { 'target' => target, 'type' => 'Package', 'title' => 'openssl' } }
  let(:resource) { Bolt::ResourceInstance.new(hash) }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should return nil if the resource is not found' do
    is_expected.to run.with_params(target, 'Foo', 'bar').and_return(nil)
  end

  it 'should return the resource if it is found' do
    target.set_resource(resource)
    is_expected.to run.with_params(*hash.values)
                      .and_return(resource)
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('resource')
    is_expected.to run.with_params(target, 'Foo', 'bar')
  end
end
