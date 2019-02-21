# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'wait_until_available' do
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:target) { Bolt::Target.new('test.example.com') }
  let(:tasks_enabled) { true }
  let(:result_set) { Bolt::ResultSet.new([Bolt::Result.new(target)]) }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'with bolt feature present' do
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'calls executor wait_until_available' do
      executor.expects(:wait_until_available).with([target], anything).returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run.with_params(target).and_return(result_set)
    end

    it 'passes extra parameters' do
      executor.expects(:wait_until_available)
              .with([target], description: 'desc', wait_time: 5, retry_interval: 0)
              .returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run.with_params(target, 'description' => 'desc', 'wait_time' => 5, 'retry_interval' => 0)
                        .and_return(result_set)
    end

    it 'errors on unknown parameters' do
      inventory.expects(:get_targets).with(target).returns([target])
      is_expected.to run.with_params(target, 'foo' => true)
                        .and_raise_error(/unknown keyword: foo/)
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      is_expected.to run.with_params('echo hello')
                        .and_raise_error(/The 'bolt' library is required to wait until targets are available/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that wait_until_available is not available' do
      is_expected.to run
        .with_params(target).and_raise_error(/Plan language function 'wait_until_available' cannot be used/)
    end
  end
end
