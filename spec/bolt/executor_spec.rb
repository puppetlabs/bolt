require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:config) { Bolt::Config.new }
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

  def mock_node(name, target, run_as)
    double(name, class: transport, connect: nil, disconnect: nil, uri: name, target: target, run_as: run_as)
  end

  def mock_node_results(run_as = nil)
    {
      mock_node('node1', targets[0], run_as) => Bolt::Result.new(targets[0]),
      mock_node('node2', targets[1], run_as) => Bolt::Result.new(targets[0])
    }
  end

  let(:targets) { [double('target1'), double('target2')] }
  let(:node_results) { mock_node_results }

  before(:each) do
    allow(executor).to receive(:from_targets).with(targets).and_return(node_results.map(&:first))
  end

  context 'running a command' do
    it 'executes on all nodes' do
      node_results.each do |node, result|
        expect(node).to receive(:run_command).with(command, {}).and_return(result)
      end

      executor.run_command(targets, command, {})
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |node, result|
        expect(node).to receive(:run_command).with(command, '_run_as' => 'foo').and_return(result)
      end

      executor.run_command(targets, command)
    end

    context 'nodes with run_as' do
      let(:node_results) { mock_node_results('foo') }

      it 'does not pass _run_as' do
        executor.run_as = 'foo'
        node_results.each do |node, result|
          expect(node).to receive(:run_command).with(command, {}).and_return(result)
        end

        executor.run_command(targets, command)
      end
    end

    it "yields each result" do
      node_results.each do |node, result|
        expect(node).to receive(:run_command).with(command, {}).and_return(result)
      end

      results = []
      executor.run_command(targets, command) do |result|
        results << result
      end

      node_results.each do |node, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(node.target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |node|
        expect(node).to receive(:run_command).with(command, {}).and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.run_command(targets, command) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'executes running a script' do
    it "on all nodes" do
      node_results.each do |node, result|
        expect(node).to receive(:run_script).with(script, [], {}).and_return(result)
      end

      results = executor.run_script(targets, script, [], {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |node, result|
        expect(node).to receive(:run_script).with(script, [], '_run_as' => 'foo').and_return(result)
      end

      results = executor.run_script(targets, script, [])
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    context 'nodes with run_as' do
      let(:node_results) { mock_node_results('foo') }

      it 'does not pass _run_as' do
        executor.run_as = 'foo'
        node_results.each do |node, result|
          expect(node).to receive(:run_script).with(script, [], {}).and_return(result)
        end

        results = executor.run_script(targets, script, [])
        results.each do |result|
          expect(result).to be_instance_of(Bolt::Result)
        end
      end
    end

    it "yields each result" do
      node_results.each do |node, result|
        expect(node).to receive(:run_script).with(script, [], {}).and_return(result)
      end

      results = []
      executor.run_script(targets, script, []) do |result|
        results << result
      end

      node_results.each do |node, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(node.target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |node|
        expect(node).to receive(:run_script).with(script, [], {}).and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.run_script(targets, script, []) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'running a task' do
    it "executes on all nodes" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:run_task)
          .with(task, 'both', task_arguments, {})
          .and_return(result)
      end

      results = executor.run_task(targets, task, 'both', task_arguments, {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'passes _run_as' do
      executor.run_as = 'foo'
      node_results.each do |node, result|
        expect(node)
          .to receive(:run_task)
          .with(task, 'both', task_arguments, '_run_as' => 'foo')
          .and_return(result)
      end

      results = executor.run_task(targets, task, 'both', task_arguments, {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    context 'nodes with run_as' do
      let(:node_results) { mock_node_results('foo') }

      it 'does not pass _run_as' do
        executor.run_as = 'foo'
        node_results.each do |node, result|
          expect(node)
            .to receive(:run_task)
            .with(task, 'both', task_arguments, {})
            .and_return(result)
        end

        results = executor.run_task(targets, task, 'both', task_arguments, {})
        results.each do |result|
          expect(result).to be_instance_of(Bolt::Result)
        end
      end
    end

    it "yields each result" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:run_task)
          .with(task, 'both', task_arguments, {})
          .and_return(result)
      end

      results = []
      executor.run_task(targets, task, 'both', task_arguments) do |result|
        results << result
      end
      node_results.each do |node, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(node.target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |node|
        expect(node)
          .to receive(:run_task)
          .with(task, 'both', task_arguments, {})
          .and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.run_task(targets, task, 'both', task_arguments) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'uploading a file' do
    it "executes on all nodes" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:upload)
          .with(script, dest, {})
          .and_return(result)
      end

      results = executor.file_upload(targets, script, dest)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:upload)
          .with(script, dest, {})
          .and_return(result)
      end

      results = []
      executor.file_upload(targets, script, dest) do |result|
        results << result
      end
      node_results.each do |node, result|
        expect(results).to include(success_event(result))
        expect(results).to include(start_event(node.target))
      end
    end

    it 'catches errors' do
      node_results.each_key do |node|
        expect(node)
          .to receive(:upload)
          .with(script, dest, {})
          .and_raise(Bolt::Error, 'failed', 'my-exception')
      end

      executor.file_upload(targets, script, dest) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  it "returns an error result" do
    node_results.each_key do |node|
      expect(node)
        .to receive(:connect)
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
    logger = double('logger', error: nil)
    node_results.each_key do |node|
      allow(node).to receive(:logger).and_return(logger)
      expect(node).to receive(:connect).and_raise("reset")
    end

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end

  context "When running a plan" do
    let(:executor) { Bolt::Executor.new(config, nil, true) }
    let(:nodes_string) { node_results.map(&:first).map(&:uri) }

    it "logs commands" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:run_command)
          .with(command, {})
          .and_return(result)
      end

      executor.run_command(targets, command)

      expect(@log_output.readline).to match(/INFO.*Starting command run .* on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran command .* on 2 nodes with 0 failures/)
    end

    it "logs scripts" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:run_script)
          .with(script, [], {})
          .and_return(result)
      end

      executor.run_script(targets, script, [])

      expect(@log_output.readline).to match(/INFO.*Starting script run .* on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran script .* on 2 nodes with 0 failures/)
    end

    it "logs tasks" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:run_task)
          .with(task, 'both', task_arguments, {})
          .and_return(result)
      end

      executor.run_task(targets, task, 'both', task_arguments)

      expect(@log_output.readline).to match(/INFO.*Starting task service::restart on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran task 'service::restart' on 2 nodes with 0 failures/)
    end

    it "logs uploads" do
      node_results.each do |node, result|
        expect(node)
          .to receive(:upload)
          .with(script, dest, {})
          .and_return(result)
      end

      executor.file_upload(targets, script, dest)

      expect(@log_output.readline).to match(/INFO.*Starting file upload from .* to .* on .*/)
      expect(@log_output.readline).to match(/INFO.*Ran upload .* on 2 nodes with 0 failures/)
    end
  end
end
