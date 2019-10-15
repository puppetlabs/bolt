# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'

describe 'run_command' do
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      inventory.stubs(:version).returns(1)
      example.run
    end
  end

  context 'it calls bolt executor run_command' do
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.new(hostname) }
    let(:command) { 'hostname' }
    let(:result) { Bolt::Result.new(target, value: { 'stdout' => hostname }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with given command and host' do
      executor.expects(:run_command).with([target], command, {}).returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params(command, hostname).and_return(result_set)
    end

    it 'with given command and Target' do
      executor.expects(:run_command).with([target], command, {}).returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run.with_params(command, target).and_return(result_set)
    end

    it 'with _run_as' do
      executor.expects(:run_command).with([target], command, run_as: 'root').returns(result_set)
      inventory.expects(:get_targets).with(target).returns([target])

      is_expected.to run.with_params(command, target, '_run_as' => 'root').and_return(result_set)
    end

    it 'reports the call to analytics' do
      executor.expects(:report_function_call).with('run_command')
      executor.expects(:run_command).with([target], command, {}).returns(result_set)
      inventory.expects(:get_targets).with(hostname).returns([target])

      is_expected.to run.with_params(command, hostname).and_return(result_set)
    end

    context 'with description' do
      let(:message) { 'test message' }

      it 'passes the description through if parameters are passed' do
        executor.expects(:run_command).with([target], command, description: message).returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run.with_params(command, target, message, {}).and_return(result_set)
      end

      it 'passes the description through if no parameters are passed' do
        executor.expects(:run_command).with([target], command, description: message).returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run.with_params(command, target, message).and_return(result_set)
      end
    end

    context 'without description' do
      it 'ignores description if parameters are passed' do
        executor.expects(:run_command).with([target], command, {}).returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run.with_params(command, target, {}).and_return(result_set)
      end

      it 'ignores description if no parameters are passed' do
        executor.expects(:run_command).with([target], command, {}).returns(result_set)
        inventory.expects(:get_targets).with(target).returns([target])

        is_expected.to run.with_params(command, target).and_return(result_set)
      end
    end

    context 'with multiple hosts' do
      let(:hostname2) { 'test.testing.com' }
      let(:target2) { Bolt::Target.new(hostname2) }
      let(:result2) { Bolt::Result.new(target2, value: { 'stdout' => hostname2 }) }
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'with propagates multiple hosts and returns multiple results' do
        executor.expects(:run_command).with([target, target2], command, {}).returns(result_set)
                .returns(result_set)
        inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

        is_expected.to run.with_params(command, [hostname, hostname2]).and_return(result_set)
      end

      it 'with propagates multiple Targets and returns multiple results' do
        executor.expects(:run_command).with([target, target2], command, {}).returns(result_set)
        inventory.expects(:get_targets).with([target, target2]).returns([target, target2])

        is_expected.to run.with_params(command, [target, target2]).and_return(result_set)
      end

      context 'when a command fails on one node' do
        let(:result2) { Bolt::Result.new(target2, error: { 'message' => hostname2 }) }

        it 'errors by default' do
          executor.expects(:run_command).with([target, target2], command, {})
                  .returns(result_set)
          inventory.expects(:get_targets).with([target, target2]).returns([target, target2])

          is_expected.to run.with_params(command, [target, target2]).and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executor.expects(:run_command).with([target, target2], command, catch_errors: true)
                  .returns(result_set)
          inventory.expects(:get_targets).with([hostname, hostname2]).returns([target, target2])

          is_expected.to run.with_params(command, [hostname, hostname2], '_catch_errors' => true)
        end
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:run_command).never
      inventory.expects(:get_targets).with([]).returns([])

      is_expected.to run.with_params(command, []).and_return(Bolt::ResultSet.new([]))
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that run_command is not available' do
      is_expected.to run.with_params('echo hello', [])
                        .and_raise_error(/Plan language function 'run_command' cannot be used/)
    end
  end
end
