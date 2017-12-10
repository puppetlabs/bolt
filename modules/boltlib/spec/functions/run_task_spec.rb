require 'spec_helper'
require 'puppet/pops/types/execution_result'

describe 'run_task' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { mock('bolt_executor') }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  context 'it calls bolt with executor, input method, and arguments' do
    let(:hostname) { 'a.b.com' }
    let(:hostname2) { 'x.y.com' }
    let(:message) { 'the message' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:host2) { stub(uri: hostname2) }
    let(:result) { { value: message } }
    let(:exec_result) { Puppet::Pops::Types::ExecutionResult.from_bolt(host => result) }
    let(:tasks_root) { File.expand_path(fixtures('modules', 'test', 'tasks')) }

    it 'when running a task without metadata the input method is "both"' do
      executable = File.join(tasks_root, 'echo.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'both', 'message' => message).returns(host => result)

      is_expected.to run.with_params('Test::Echo', hostname, 'message' => message).and_return(exec_result)
    end

    it 'when running a task with metadata - the input method is specified by the metadata' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'environment', 'message' => message).returns(host => result)

      is_expected.to run.with_params('Test::Meta', hostname, 'message' => message).and_return(exec_result)
    end

    it 'when called without without args hash (for a task where this is allowed)' do
      executable = File.join(tasks_root, 'yes.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'both', {}).returns(host => result)

      is_expected.to run.with_params('test::yes', hostname).and_return(exec_result)
    end

    it 'when called with no destinations - does not invoke bolt' do
      executor.expects(:from_uris).never
      executor.expects(:run_task).never

      is_expected.to run.with_params('Test::Yes', []).and_return(Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT)
    end

    context 'with multiple destinations' do
      let(:exec_result) { Puppet::Pops::Types::ExecutionResult.from_bolt(host => result, host2 => result) }

      it 'nodes can be specified as repeated nested arrays and strings and combine into one list of nodes' do
        executable = File.join(tasks_root, 'meta.sh')

        executor.expects(:from_uris).with([hostname, hostname2]).returns([host, host2])
        executor.expects(:run_task).with([host, host2], executable, 'environment', 'message' => message)
                .returns(host => result, host2 => result)

        is_expected.to run.with_params('Test::Meta', [hostname, [[hostname2]], []], 'message' => message)
                          .and_return(exec_result)
      end

      it 'nodes can be specified as repeated nested arrays and Targets and combine into one list of nodes' do
        executable = File.join(tasks_root, 'meta.sh')

        executor.expects(:from_uris).with([hostname, hostname2]).returns([host, host2])
        executor.expects(:run_task).with([host, host2], executable, 'environment', 'message' => message)
                .returns(host => result, host2 => result)

        target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
        target2 = Puppet::Pops::Types::TypeFactory.target.create(hostname2)
        is_expected.to run.with_params('Test::Meta', [target, [[target2]], []], 'message' => message)
                          .and_return(exec_result)
      end
    end

    context 'when called on a module that contains manifests/init.pp' do
      it 'the call does not load init.pp' do
        executor.expects(:from_uris).never
        executor.expects(:run_task).never

        is_expected.to run.with_params('test::echo', [])
      end
    end

    context 'when called on a module that contains tasks/init.sh' do
      it 'finds task named after the module' do
        executable = File.join(tasks_root, 'init.sh')

        executor.expects(:from_uris).with(hosts).returns([host])
        executor.expects(:run_task).with([host], executable, 'both', {}).returns(host => result)

        is_expected.to run.with_params('test', hostname).and_return(exec_result)
      end
    end

    it 'when called with non existing task - reports an unknown task error' do
      is_expected.to run.with_params('test::nonesuch', []).and_raise_error(/Task not found: test::nonesuch/)
    end
  end
end
