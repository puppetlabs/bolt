require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:config) { Bolt::Config.new }
  let(:executor) { Bolt::Executor.new(config) }
  let(:command) { "hostname" }
  let(:script) { '/path/to/script.sh' }
  let(:success) { Bolt::Node::Success.new }
  let(:task) { 'service::restart' }
  let(:task_arguments) { { 'name' => 'apache' } }
  let(:nodes) { [mock_node('node1'), mock_node('node2')] }

  def mock_node(name)
    transport = double('holodeck')
    allow(transport).to receive(:initialize_transport)

    node = double(name, name: name)
    allow(node).to receive(:class).and_return(transport)
    allow(node).to receive(:connect)
    allow(node).to receive(:disconnect)
    node
  end

  it "executes a command on all nodes" do
    nodes.each do |node|
      expect(node).to receive(:run_command).with(command).and_return(success)
    end

    executor.run_command(nodes, command)
  end

  it "yields each command result" do
    nodes.each do |node|
      expect(node).to receive(:run_command).with(command).and_return(success)
    end

    results = []
    executor.run_command(nodes, command) do |node, result|
      results << [node, result]
    end

    expect(results).to match_array(nodes.zip(Array.new(nodes.length, success)))
  end

  it "runs a script on all nodes" do
    nodes.each do |node|
      expect(node).to receive(:run_script).with(script, []).and_return(success)
    end

    results = executor.run_script(nodes, script, [])
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Node::Success)
    end
  end

  it "yields each script result" do
    nodes.each do |node|
      expect(node).to receive(:run_script).with(script, []).and_return(success)
    end

    results = []
    executor.run_script(nodes, script, []) do |node, result|
      results << [node, result]
    end

    expect(results).to match_array(nodes.zip(Array.new(nodes.length, success)))
  end

  it "runs a task on all nodes" do
    nodes.each do |node|
      expect(node)
        .to receive(:run_task)
        .with(task, 'both', task_arguments)
        .and_return(success)
    end

    results = executor.run_task(nodes, task, 'both', task_arguments)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Node::Success)
    end
  end

  it "yields each task result" do
    nodes.each do |node|
      expect(node)
        .to receive(:run_task)
        .with(task, 'both', task_arguments)
        .and_return(success)
    end

    results = []
    executor.run_task(nodes, task, 'both', task_arguments) do |node, result|
      results << [node, result]
    end
    expect(results).to match_array(nodes.zip(Array.new(nodes.length, success)))
  end

  it "returns an error result if the connect raises a base error" do
    node = mock_node 'node'
    expect(node)
      .to receive(:connect)
      .and_raise(
        Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
      )

    results = executor.run_command([node], command)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::ErrorResult)
    end
  end

  it "returns an exception result if the connect raises an unhandled error" do
    logger = double('logger', error: nil)
    node = mock_node 'node'
    allow(node).to receive(:logger).and_return(logger)
    expect(node).to receive(:connect).and_raise("reset")

    results = executor.run_command([node], command)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::ExceptionResult)
    end
  end

  it "generates node objects from a list of uris" do
    expect(Bolt::SSH).to receive(:new).with('a.net', any_args)
    expect(Bolt::WinRM).to receive(:new).with('b.com', any_args)

    executor.from_uris(['ssh://a.net', 'winrm://b.com'])
  end
end
