require 'spec_helper'
require 'puppet/pops/types/execution_result'

def with_task(task)
  env = Puppet.lookup(:current_environment)
  loaders = Puppet::Pops::Loaders.new(env)
  Puppet.push_context({ loaders: loaders }, "test-examples")

  task_type = Puppet.lookup(:loaders).private_environment_loader.load(:type, task)
  yield task_type

  Puppet::Pops::Loaders.clear
  Puppet.pop_context
end

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
    let(:exec_result) { stub('exec_result') }
    let(:tasks_root) { File.expand_path(fixtures('modules', 'test', 'tasks')) }

    it 'when running a task without metadata the input method is "both"' do
      executable = File.join(tasks_root, 'echo.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'both', 'message' => message).returns(host: result)
      Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

      with_task('Test::Echo') do |task_type|
        is_expected.to run.with_params(task_type.create('message' => message), hostname).and_return(exec_result)
      end
    end

    it 'when running a task with metadata - the input method is specified by the metadata' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'environment', 'message' => message).returns(host: result)
      Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

      with_task('Test::Meta') do |task_type|
        is_expected.to run.with_params(task_type.create(message), hostname).and_return(exec_result)
      end
    end

    it 'nodes can be specified as repeated nested arrays and strings and combine into one list of nodes' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:from_uris).with([hostname, hostname2]).returns([host, host2])
      executor.expects(:run_task).with([host, host2], executable, 'environment', 'message' => message)
              .returns(host: result, host2: result)
      Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result, host2: result).returns(exec_result)

      with_task('Test::Meta') do |task_type|
        is_expected.to run.with_params(task_type.create(message), hostname, [[hostname2]], []).and_return(exec_result)
      end
    end

    it 'nodes can be specified as repeated nested arrays and Targets and combine into one list of nodes' do
      executable = File.join(tasks_root, 'meta.sh')

      executor.expects(:from_uris).with([hostname, hostname2]).returns([host, host2])
      executor.expects(:run_task).with([host, host2], executable, 'environment', 'message' => message)
              .returns(host: result, host2: result)
      Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result, host2: result).returns(exec_result)

      target = Puppet::Pops::Types::TypeFactory.target.create(hostname)
      target2 = Puppet::Pops::Types::TypeFactory.target.create(hostname2)
      with_task('Test::Meta') do |task_type|
        is_expected.to run.with_params(task_type.create(message), target, [[target2]], []).and_return(exec_result)
      end
    end

    context 'the same way as if a task instance was used; when called with' do
      context 'a task type' do
        it 'and args hash' do
          executable = File.join(tasks_root, 'meta.sh')

          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], executable, 'environment', 'message' => message)
                  .returns(host: result)
          Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

          with_task('Test::Meta') do |task_type|
            is_expected.to run.with_params(task_type, hostname, 'message' => message).and_return(exec_result)
          end
        end

        it 'without args hash (for a task where this is allowed)' do
          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], anything, 'both', {}).returns(host: result)
          Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

          with_task('Test::Yes') do |task_type|
            is_expected.to run.with_params(task_type, hostname).and_return(exec_result)
          end
        end

        it 'without nodes - does not invoke bolt' do
          executor.expects(:from_uris).never
          executor.expects(:run_task).never

          with_task('Test::Yes') do |task_type|
            is_expected.to run.with_params(task_type, []).and_return(Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT)
          end
        end
      end

      context 'a task name' do
        it 'and args hash' do
          executable = File.join(tasks_root, 'meta.sh')

          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], executable, 'environment', 'message' => message)
                  .returns(host: result)
          Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

          is_expected.to run.with_params('test::meta', hostname, 'message' => message).and_return(exec_result)
        end

        it 'without args hash (for a task where this is allowed)' do
          executable = File.join(tasks_root, 'yes.sh')

          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], executable, 'both', {}).returns(host: result)
          Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

          is_expected.to run.with_params('test::yes', hostname).and_return(exec_result)
        end

        it 'without nodes - does not invoke bolt' do
          executor.expects(:from_uris).never
          executor.expects(:run_task).never

          is_expected.to run.with_params('test::yes', []).and_return(Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT)
        end

        it 'with non existing task - reports an unknown task error' do
          is_expected.to run.with_params('test::nonesuch', []).and_raise_error(/Task not found: test::nonesuch/)
        end

        context 'on a module that contains manifests/init.pp' do
          it 'the call does not load init.pp' do
            executor.expects(:from_uris).never
            executor.expects(:run_task).never

            is_expected.to run.with_params('test::echo', [])
          end
        end

        context 'on a module that contains tasks/init.sh' do
          it 'finds task named after the module' do
            executable = File.join(tasks_root, 'init.sh')

            executor.expects(:from_uris).with(hosts).returns([host])
            executor.expects(:run_task).with([host], executable, 'both', {}).returns(host: result)
            Puppet::Pops::Types::ExecutionResult.expects(:from_bolt).with(host: result).returns(exec_result)

            is_expected.to run.with_params('test', hostname).and_return(exec_result)
          end
        end
      end
    end
  end
end
