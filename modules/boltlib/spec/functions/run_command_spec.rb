require 'spec_helper'
require 'puppet/pops/types/execution_result'

describe 'run_command' do
  let(:executor) { mock('bolt_executor') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(:bolt_executor => executor) do
      example.run
    end
  end

  context 'it calls bolt executor run_command' do
    let(:hostname) { 'test.example.com' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:command) { 'hostname' }
    let(:result) { { value: hostname } }
    let(:exec_result) { stub('exec_result') }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with given command and host' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_command).with([host], command).returns({ host => result })
      Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with({ host => result }).returns(exec_result)

      is_expected.to run.with_params(command, hostname).and_return(exec_result)
    end

    it 'with given command and Target' do
      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_command).with([host], command).returns({ host => result })
      Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with({ host => result }).returns(exec_result)

      target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
      is_expected.to run.with_params(command, target).and_return(exec_result)
    end

    context 'with multiple hosts' do
      let(:hostname2) { 'test.testing.com' }
      let(:hosts) { [hostname, hostname2] }
      let(:host2) { stub(uri: hostname2) }
      let(:result2) { { value: hostname2 } }

      it 'with propagates multiple hosts and returns multiple results' do
        executor.expects(:from_uris).with(hosts).returns([host, host2])
        executor.expects(:run_command).with([host, host2], command).returns({ host => result, host2 => result2 })
        Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with({ host => result, host2 => result2 }).returns(exec_result)

        is_expected.to run.with_params(command, hostname, hostname2).and_return(exec_result)
      end

      it 'with propagates multiple Targets and returns multiple results' do
        executor.expects(:from_uris).with(hosts).returns([host, host2])
        executor.expects(:run_command).with([host, host2], command).returns({ host => result, host2 => result2 })
        Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with({ host => result, host2 => result2 }).returns(exec_result)

        target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
        target2 = Puppet::Pops::Types::TypeFactory.target.create(hostname2)
        is_expected.to run.with_params(command, target, target2).and_return(exec_result)
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:from_uris).never
      executor.expects(:run_command).never

      is_expected.to run.with_params(command).and_return(Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT)
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      is_expected.to run.with_params('echo hello').and_raise_error(/The 'bolt' library is required to run a command/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that run_command is not available' do
      is_expected.to run.with_params('echo hello').and_raise_error(/The task operation 'run_command' is not available/)
    end
  end
end
