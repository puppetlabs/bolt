require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:config) { Bolt::Config.new }
  let(:executor) { Bolt::Executor.new(config) }
  let(:command) { "hostname" }
  let(:script) { '/path/to/script.sh' }
  let(:dest) { '/tmp/upload' }
  let(:success) { Bolt::Result.new }
  let(:start_event) { { type: :node_start } }
  let(:success_event) { { type: :node_result, result: success } }
  let(:task) { 'service::restart' }
  let(:task_arguments) { { 'name' => 'apache' } }
  let(:nodes) { [mock_node('node1'), mock_node('node2')] }

  def mock_node(name)
    transport = double('holodeck')
    allow(transport).to receive(:initialize_transport)
    allow(transport).to receive(:name)

    node = double(name, name: name)
    allow(node).to receive(:class).and_return(transport)
    allow(node).to receive(:connect)
    allow(node).to receive(:disconnect)
    allow(node).to receive(:uri).and_return(name)
    node
  end

  it "executes a command on all nodes" do
    nodes.each do |node|
      allow(node).to receive(:uri)
      expect(node).to receive(:run_command).with(command).and_return(success)
    end

    executor.run_command(nodes, command)
  end

  it "yields each command result" do
    nodes.each do |node|
      allow(node).to receive(:uri)
      expect(node).to receive(:run_command).with(command).and_return(success)
    end

    results = []
    executor.run_command(nodes, command) do |node, result|
      allow(node).to receive(:uri)
      results << [node, result]
    end

    nodes.each do |node|
      expect(results).to include([node, success_event])
      expect(results).to include([node, start_event])
    end
  end

  it "runs a script on all nodes" do
    nodes.each do |node|
      allow(node).to receive(:uri)
      expect(node).to receive(:run_script).with(script, []).and_return(success)
    end

    results = executor.run_script(nodes, script, [])
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Result)
    end
  end

  it "yields each script result" do
    nodes.each do |node|
      allow(node).to receive(:uri)
      expect(node).to receive(:run_script).with(script, []).and_return(success)
    end

    results = []
    executor.run_script(nodes, script, []) do |node, result|
      results << [node, result]
    end

    nodes.each do |node|
      expect(results).to include([node, success_event])
      expect(results).to include([node, start_event])
    end
  end

  it "runs a task on all nodes" do
    nodes.each do |node|
      allow(node).to receive(:uri)
      expect(node)
        .to receive(:run_task)
        .with(task, 'both', task_arguments)
        .and_return(success)
    end

    results = executor.run_task(nodes, task, 'both', task_arguments)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Result)
    end
  end

  it "yields each task result" do
    nodes.each do |node|
      allow(node).to receive(:uri)
      expect(node)
        .to receive(:run_task)
        .with(task, 'both', task_arguments)
        .and_return(success)
    end

    results = []
    executor.run_task(nodes, task, 'both', task_arguments) do |node, result|
      results << [node, result]
    end
    nodes.each do |node|
      expect(results).to include([node, success_event])
      expect(results).to include([node, start_event])
    end
  end

  it "returns an error result if the connect raises a base error" do
    node = mock_node 'node'
    allow(node).to receive(:uri)
    expect(node)
      .to receive(:connect)
      .and_raise(
        Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
      )

    results = executor.run_command([node], command)
    results.each_pair do |_, result|
      expect(result.error['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  it "returns an exception result if the connect raises an unhandled error" do
    logger = double('logger', error: nil)
    node = mock_node 'node'
    allow(node).to receive(:logger).and_return(logger)
    allow(node).to receive(:uri)
    expect(node).to receive(:connect).and_raise("reset")

    results = executor.run_command([node], command)
    results.each_pair do |_, result|
      expect(result.error['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end

  it "generates node objects from a list of uris" do
    expect(Bolt::SSH).to receive(:new).with('a.net', any_args)
    expect(Bolt::WinRM).to receive(:new).with('b.com', any_args)

    executor.from_uris(['ssh://a.net', 'winrm://b.com'])
  end

  context "When running a plan" do
    let(:executor) { Bolt::Executor.new(config, nil, true) }
    let(:nodes_string) { nodes.map(&:uri) }

    it "logs commands" do
      nodes.each do |node|
        expect(node)
          .to receive(:run_command)
          .with(command)
          .and_return(success)
      end

      logger = double('logger')
      allow(logger).to receive(:debug)
      expect(logger).to receive(:log).with(Logger::NOTICE, "Starting command run '#{command}' on #{nodes_string}")
      expect(logger).to receive(:log).with(Logger::NOTICE, "Ran command '#{command}' on 2 nodes with 0 failures")
      allow(Logger).to receive(:get_logger).and_return(logger)

      executor.run_command(nodes, command)
    end

    it "logs scripts" do
      nodes.each do |node|
        expect(node)
          .to receive(:run_script)
          .with(script, [])
          .and_return(success)
      end

      logger = double('logger')
      allow(logger).to receive(:debug)
      expect(logger).to receive(:log).with(Logger::NOTICE, "Starting script run #{script} on #{nodes_string}")
      expect(logger).to receive(:log).with(Logger::NOTICE, "Ran script '#{script}' on 2 nodes with 0 failures")
      allow(Logger).to receive(:get_logger).and_return(logger)

      executor.run_script(nodes, script, [])
    end

    it "logs tasks" do
      nodes.each do |node|
        expect(node)
          .to receive(:run_task)
          .with(task, 'both', task_arguments)
          .and_return(success)
      end

      logger = double('logger')
      allow(logger).to receive(:debug)
      expect(logger).to receive(:log).with(Logger::NOTICE, 'Starting task service::restart on ["node1", "node2"]')
      expect(logger).to receive(:log).with(Logger::NOTICE, "Ran task 'service::restart' on 2 nodes with 0 failures")
      allow(Logger).to receive(:get_logger).and_return(logger)

      executor.run_task(nodes, task, 'both', task_arguments)
    end

    it "logs uploads" do
      nodes.each do |node|
        expect(node)
          .to receive(:upload)
          .with(script, dest)
          .and_return(success)
      end

      logger = double('logger')
      allow(logger).to receive(:debug)
      expect(logger).to receive(:log).with(Logger::NOTICE,
                                           "Starting file upload from #{script} to #{dest} on #{nodes_string}")
      expect(logger).to receive(:log).with(Logger::NOTICE, "Ran upload '#{script}' on 2 nodes with 0 failures")
      allow(Logger).to receive(:get_logger).and_return(logger)

      executor.file_upload(nodes, script, dest)
    end
  end
end
