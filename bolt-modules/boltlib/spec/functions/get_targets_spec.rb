# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'get_targets' do
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'it calls inventory get_targets' do
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }

    it 'with given host' do
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params(hostname).and_return([target])
    end

    it 'with given Target' do
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run.with_params(target).and_return([target])
    end

    it 'with array of hosts' do
      inventory.expects(:get_targets).with([hostname]).returns([target])

      is_expected.to run.with_params([hostname]).and_return([target])
    end

    it 'with array of Targets' do
      inventory.expects(:get_targets).with([target]).returns([target])

      is_expected.to run.with_params([target]).and_return([target])
    end

    it 'with comma-separated hosts' do
      inventory.expects(:get_targets).with("#{hostname},group").returns([target])

      is_expected.to run.with_params("#{hostname},group").and_return([target])
    end

    it 'errors on unknown types' do
      is_expected.to run.with_params(mock('anything')).and_raise_error(ArgumentError)
    end

    it 'reports the call to analytics' do
      inventory.expects(:get_targets).with(hostname).returns([target])
      executor.expects(:report_function_call).with('get_targets')

      is_expected.to run.with_params(hostname).and_return([target])
    end
  end
end
