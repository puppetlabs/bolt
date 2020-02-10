# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'get_targets' do
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'it calls inventory get_targets' do
    let(:hostname) { 'test.example.com' }
    let(:hostname2) { 'test2.example.com' }
    let(:target) { inventory.get_target(hostname) }
    let(:target2) { inventory.get_target(hostname2) }

    it 'with given host' do
      is_expected.to run.with_params(hostname).and_return([target])
    end

    it 'with given Target' do
      is_expected.to run.with_params(target).and_return([target])
    end

    it 'with array of hosts' do
      is_expected.to run.with_params([hostname]).and_return([target])
    end

    it 'with array of Targets' do
      is_expected.to run.with_params([target]).and_return([target])
    end

    it 'with comma-separated hosts' do
      is_expected.to run.with_params("#{hostname},#{hostname2}").and_return([target, target2])
    end

    it 'errors on unknown types' do
      is_expected.to run.with_params(mock('anything')).and_raise_error(ArgumentError)
    end

    it 'reports the call to analytics' do
      executor.expects(:report_function_call).with('get_targets')
      is_expected.to run.with_params(hostname).and_return([target])
    end
  end
end
