# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'bolt/executor'

describe "Bolt::Executor" do
  include BoltSpec::Task

  let(:analytics) { Bolt::Analytics::NoopClient.new }
  let(:executor) { Bolt::Executor.new(1, analytics) }
  let(:command) { "hostname" }
  let(:script) { '/path/to/script.sh' }
  let(:dest) { '/tmp/upload' }
  let(:task) { 'service::restart' }
  let(:task_arguments) { { 'name' => 'apache' } }
  let(:transport) { double('holodeck', initialize_transport: nil) }

  def start_event(target)
    { type: :node_start, target: target }
  end

  def success_event(result)
    { type: :node_result, result: result }
  end

  def mock_node_results(_run_as = nil)
    {
      targets[0] => Bolt::Result.new(targets[0]),
      targets[1] => Bolt::Result.new(targets[1])
    }
  end

  let(:targets) { [Bolt::Target.new("target1"), Bolt::Target.new("target2")] }
  let(:node_results) { mock_node_results }
  let(:ssh) { executor.transport('ssh') }

  context 'running a command' do
    it 'executes on all nodes' do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_command).with(target, command, {}).and_return(result)
      end

      executor.run_command(targets, command, {})
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh).to receive(:run_command).with(target, command, '_run_as' => 'foo').and_return(result)
      end

      executor.run_command(targets, command)
    end

    context 'nodes with run_as' do
      let(:targets) {
        [Bolt::Target.new("target1", 'run-as' => 'foo'),
         Bolt::Target.new("target2", 'run-as' => 'foo')]
      }

      it 'does not pass _run_as' do
        executor.run_as = 'foo'
        node_results.each do |target, result|
          expect(ssh).to receive(:run_command).with(target, command, {}).and_return(result)
        end

        executor.run_command(targets, command)
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_command).with(target, command, {}).and_return(result)
      end

      results = []
      executor.run_command(targets, command) do |result|
        results << result
      end

      node_results.each do |target, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh).to receive(:run_command).with(target, command, {}).and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.run_command(targets, command) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'executes running a script' do
    it "on all nodes" do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_script).with(target, script, [], {}).and_return(result)
      end

      results = executor.run_script(targets, script, [], {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh).to receive(:run_script).with(target, script, [], '_run_as' => 'foo').and_return(result)
      end

      results = executor.run_script(targets, script, [])
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    context 'nodes with run_as' do
      let(:targets) {
        [Bolt::Target.new("target1", 'run-as' => 'foo'),
         Bolt::Target.new("target2", 'run-as' => 'foo')]
      }

      it 'does not pass _run_as' do
        executor.run_as = 'foo'
        node_results.each do |target, result|
          expect(ssh).to receive(:run_script).with(target, script, [], {}).and_return(result)
        end

        results = executor.run_script(targets, script, [])
        results.each do |result|
          expect(result).to be_instance_of(Bolt::Result)
        end
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh).to receive(:run_script).with(target, script, [], {}).and_return(result)
      end

      results = []
      executor.run_script(targets, script, []) do |result|
        results << result
      end

      node_results.each do |target, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:run_script)
          .with(target, script, [], {})
          .and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.run_script(targets, script, []) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'running a task' do
    it "executes on all nodes" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, {})
          .and_return(result)
      end

      results = executor.run_task(targets, mock_task(task), task_arguments, {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result).to be_success
      end
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, '_run_as' => 'foo')
          .and_return(result)
      end

      results = executor.run_task(targets, mock_task(task), task_arguments, {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    context 'nodes with run_as' do
      let(:targets) {
        [Bolt::Target.new("target1", 'run-as' => 'foo'),
         Bolt::Target.new("target2")]
      }

      it 'does not pass _run_as for nodes that specify run_as' do
        executor.run_as = 'bar'
        expect(ssh)
          .to receive(:run_task)
          .with(targets[0], task_type(task), task_arguments, {})
          .and_return(node_results[targets[0]])

        expect(ssh)
          .to receive(:run_task)
          .with(targets[1], task_type(task), task_arguments, '_run_as' => 'bar')
          .and_return(node_results[targets[1]])

        results = executor.run_task(targets, mock_task(task), task_arguments, {})
        results.each do |result|
          expect(result).to be_instance_of(Bolt::Result)
        end
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, {})
          .and_return(result)
      end

      results = []
      executor.run_task(targets, mock_task(task), task_arguments) do |result|
        results << result
      end
      node_results.each do |target, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, {})
          .and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.run_task(targets, mock_task(task), task_arguments) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'uploading a file' do
    it "executes on all nodes" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      results = executor.file_upload(targets, script, dest)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      results = []
      executor.file_upload(targets, script, dest) do |result|
        results << result
      end
      node_results.each do |target, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |target|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.file_upload(targets, script, dest) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  it "returns an error result" do
    node_results.each_key do |_target|
      expect(ssh)
        .to receive(:with_connection)
        .and_raise(
          Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
        )
    end

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  context "targets with different protocols" do
    let(:targets) {
      [Bolt::Target.new('ssh://node1'), Bolt::Target.new('winrm://node2'), Bolt::Target.new('pcp://node3')]
    }

    it "returns ensures that every target has a result, no matter what" do
      result_set = executor.batch_execute(targets) do
        # Intentionally *don't* return a result
        []
      end

      expect(result_set.names).to eq(targets.map(&:name))
      result_set.each do |result|
        expect(result).not_to be_success
        expect(result.error_hash['msg']).to match(/No result was returned/)
      end
    end
  end

  context "with concurrency 2" do
    let(:targets) {
      [Bolt::Target.new('node1'), Bolt::Target.new('node2'), Bolt::Target.new('node3')]
    }

    let(:executor) { Bolt::Executor.new(2, analytics) }

    it "batch_execute only creates 2 threads" do
      state = targets.each_with_object({}) do |target, acc|
        acc[target] = { promise: Concurrent::Promise.new { Bolt::Result.for_command(target, "foo", "bar", 0) },
                        running: false }
      end

      # calling promise.value will block the thread from completing
      t = Thread.new {
        executor.batch_execute(targets) do |_transport, batch|
          target = batch[0]
          state[target][:running] = true
          result = state[target][:promise].value
          state[target][:running] = false
          result
        end
      }
      # without pausing here running seems to evaluate to 0
      sleep(0.1)

      running = state.reduce(0) do |acc, (_k, v)|
        acc += 1 if v[:running]
        acc
      end

      expect(running).to eq(2)
      # execute all the promises to release the threads
      state.keys.each { |k| state[k][:promise].execute }
      t.join
    end
  end

  it "returns an exception result if the connect raises an unhandled error" do
    node_results.each_key do |_target|
      expect(ssh).to receive(:with_connection).and_raise("reset")
    end

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end

  context 'reporting analytics data' do
    let(:targets) {
      [Bolt::Target.new('ssh://node1'),
       Bolt::Target.new('ssh://node2'),
       Bolt::Target.new('winrm://node3'),
       Bolt::Target.new('pcp://node4')]
    }

    it 'reports one event for each transport used' do
      expect(analytics).to receive(:event).with('Transport', 'initialize', 'ssh', 2).once
      expect(analytics).to receive(:event).with('Transport', 'initialize', 'winrm', 1).once
      expect(analytics).to receive(:event).with('Transport', 'initialize', 'orch', 1).once

      executor.batch_execute(targets) {}
      executor.batch_execute(targets) {}
    end

    context "#report_function_call" do
      it 'reports an event for the given function' do
        expect(analytics).to receive(:event).with('Plan', 'call_function', 'add_facts')

        executor.report_function_call('add_facts')
      end
    end

    context "#report_bundled_content" do
      let(:executor) { Bolt::Executor.new(2, analytics, bundled_content: %w[canary facts]) }

      it 'reports an event when bundled plan is used' do
        expect(analytics).to receive(:event).with('Bundled Content', 'Plan', 'canary')

        executor.report_bundled_content('Plan', 'canary')
      end

      it 'reports an event when bundled task is used' do
        expect(analytics).to receive(:event).with('Bundled Content', 'Task', 'facts')

        executor.report_bundled_content('Task', 'facts')
      end

      it 'does not report a an event when non-bundled plan is used' do
        expect(analytics).to receive(:event).never

        executor.report_bundled_content('plan', 'foo')
      end

      it 'does not report a an event when non-bundled task is used' do
        expect(analytics).to receive(:event).never

        executor.report_bundled_content('task', 'foo')
      end
    end
  end

  context "When running a plan" do
    let(:nodes_string) { results.map(&:first).map(&:uri) }
    let(:plan_context) { { name: 'foo' } }

    before :all do
      @log_output.level = :notice
    end
    after :all do
      @log_output.level = :all
    end

    it "logs commands" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_command)
          .with(target, command, {})
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.run_command(targets, command)

      expect(@log_output.readline).to match(/NOTICE.*Starting: command '.*' on .*/)
      expect(@log_output.readline).to match(/NOTICE.*Finished: command '.*' with 0 failures/)
    end

    it "logs scripts" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_script)
          .with(target, script, [], {})
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.run_script(targets, script, [])

      expect(@log_output.readline).to match(/NOTICE.*Starting: script .* on .*/)
      expect(@log_output.readline).to match(/NOTICE.*Finished: script .* with 0 failures/)
    end

    it "logs tasks" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, {})
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.run_task(targets, mock_task(task), task_arguments)

      expect(@log_output.readline).to match(/NOTICE.*Starting: task service::restart on .*/)
      expect(@log_output.readline).to match(/NOTICE.*Finished: task service::restart with 0 failures/)
    end

    it "logs uploads" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      executor.start_plan(plan_context)
      executor.file_upload(targets, script, dest)

      expect(@log_output.readline).to match(/NOTICE.*Starting: file upload from .* to .* on .*/)
      expect(@log_output.readline).to match(/NOTICE.*Finished: file upload from .* to .* with 0 failures/)
    end
  end
end
