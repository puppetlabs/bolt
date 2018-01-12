require 'spec_helper'
require 'bolt/target'

describe 'run_command' do
  let(:executor) { mock('bolt_executor') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  context 'it calls bolt executor run_command' do
    let(:hostname) { 'test.example.com' }
    let(:target) { Bolt::Target.from_uri(hostname) }
    let(:command) { 'hostname' }
    let(:result) { Bolt::Result.new(target, value: { 'stdout' => hostname }) }
    let(:result_set) { Bolt::ResultSet.new([result]) }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with given command and host' do
      executor.expects(:run_command).with([target], command).returns(result_set)

      is_expected.to run.with_params(command, hostname).and_return(result_set)
    end

    it 'with given command and Target' do
      executor.expects(:run_command).with([target], command).returns(result_set)

      is_expected.to run.with_params(command, target).and_return(result_set)
    end

    context 'with multiple hosts' do
      let(:hostname2) { 'test.testing.com' }
      let(:target2) { Bolt::Target.from_uri(hostname2) }
      let(:result2) { Bolt::Result.new(target2, value: { 'stdout' => hostname2 }) }
      let(:result_set) { Bolt::ResultSet.new([result, result2]) }

      it 'with propagates multiple hosts and returns multiple results' do
        executor.expects(:run_command).with([target, target2], command).returns(result_set)

        is_expected.to run.with_params(command, [hostname, hostname2]).and_return(result_set)
      end

      it 'with propagates multiple Targets and returns multiple results' do
        executor.expects(:run_command).with([target, target2], command).returns(result_set)

        is_expected.to run.with_params(command, [target, target2]).and_return(result_set)
      end

      context 'when a command fails on one node' do
        let(:result2) { Bolt::Result.new(target2, error: { 'message' => hostname2 }) }

        it 'errors by default' do
          executor.expects(:run_command).with([target, target2], command)
                  .returns(result_set)

          is_expected.to run.with_params(command, [target, target2]).and_raise_error(Bolt::RunFailure)
        end

        it 'does not error with _catch_errors' do
          executor.expects(:run_command).with([target, target2], command)
                  .returns(result_set)

          is_expected.to run.with_params(command, [hostname, hostname2], '_catch_errors' => true)
        end
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:run_command).never

      is_expected.to run.with_params(command, []).and_return(Bolt::ResultSet.new([]))
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      is_expected.to run.with_params('echo hello', [])
                        .and_raise_error(/The 'bolt' library is required to run a command/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that run_command is not available' do
      is_expected.to run.with_params('echo hello', [])
                        .and_raise_error(/The task operation 'run_command' is not available/)
    end
  end
end
