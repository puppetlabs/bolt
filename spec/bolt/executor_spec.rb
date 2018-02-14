require 'spec_helper'
require 'bolt_spec/task'
require 'bolt/executor'

describe "Bolt::Executor" do
  include BoltSpec::Task

  let(:config) { Bolt::Config.new(concurrency: 1) }
  let(:executor) { Bolt::Executor.new(config) }
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
        [Bolt::Target.new("target1", run_as: 'foo'),
         Bolt::Target.new("target2", run_as: 'foo')]
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
        [Bolt::Target.new("target1", run_as: 'foo'),
         Bolt::Target.new("target2", run_as: 'foo')]
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
        [Bolt::Target.new("target1", run_as: 'foo'),
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

  it "returns an exception result if the connect raises an unhandled error" do
    node_results.each_key do |_target|
      expect(ssh).to receive(:with_connection).and_raise("reset")
    end

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end

  context "When running a plan" do
    let(:executor) { Bolt::Executor.new(config, nil, true) }
    let(:nodes_string) { results.map(&:first).map(&:uri) }

    it "logs commands" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_command)
          .with(target, command, {})
          .and_return(result)
      end

      executor.run_command(targets, command)

      expect(@log_output.readline).to match(/INFO.*Starting command run .* on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran command .* on 2 nodes with 0 failures/)
    end

    it "logs scripts" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_script)
          .with(target, script, [], {})
          .and_return(result)
      end

      executor.run_script(targets, script, [])

      expect(@log_output.readline).to match(/INFO.*Starting script run .* on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran script .* on 2 nodes with 0 failures/)
    end

    it "logs tasks" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:run_task)
          .with(target, task_type(task), task_arguments, {})
          .and_return(result)
      end

      executor.run_task(targets, mock_task(task), task_arguments)

      expect(@log_output.readline).to match(/INFO.*Starting task service::restart on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran task 'service::restart' on 2 nodes with 0 failures/)
    end

    it "logs uploads" do
      node_results.each do |target, result|
        expect(ssh)
          .to receive(:upload)
          .with(target, script, dest, {})
          .and_return(result)
      end

      executor.file_upload(targets, script, dest)

      expect(@log_output.readline).to match(/INFO.*Starting file upload from .* to .* on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran upload .* on 2 nodes with 0 failures/)
    end
  end
end
