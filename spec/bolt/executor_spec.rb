require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:command) { "hostname" }
  let(:script) { '/path/to/script.sh' }
  let(:success) { Bolt::Node::Success.new }
  let(:task) { 'service::restart' }
  let(:task_arguments) { { 'name' => 'apache' } }

  def mock_node(name)
    node = double(name)
    allow(node).to receive(:connect)
    allow(node).to receive(:disconnect)
    node
  end

  it "executes a command on all nodes" do
    node1 = mock_node 'node1'
    expect(node1).to receive(:run_command).with(command).and_return(success)
    node2 = mock_node 'node2'
    expect(node2).to receive(:run_command).with(command).and_return(success)

    Bolt::Executor.new([node1, node2]).run_command(command)
  end

  it "runs a script on all nodes" do
    node1 = mock_node 'node1'
    expect(node1).to receive(:run_script).with(script).and_return(success)
    node2 = mock_node 'node2'
    expect(node2).to receive(:run_script).with(script).and_return(success)

    results = Bolt::Executor.new([node1, node2]).run_script(script)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Node::Success)
    end
  end

  it "runs a task on all nodes" do
    node1 = mock_node 'node1'
    expect(node1)
      .to receive(:run_task)
      .with(task, 'both', task_arguments)
      .and_return(success)
    node2 = mock_node 'node2'
    expect(node2)
      .to receive(:run_task)
      .with(task, 'both', task_arguments)
      .and_return(success)

    results = Bolt::Executor.new([node1, node2])
                            .run_task(task, 'both', task_arguments)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Node::Success)
    end
  end

  it "returns an exception result if the connect raises" do
    logger = double('logger', error: nil)
    node = mock_node 'node'
    allow(node).to receive(:logger).and_return(logger)
    expect(node).to receive(:connect).and_raise("reset")

    results = Bolt::Executor.new([node]).run_command(command)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::ExceptionResult)
    end
  end

  it "can be created with a list of uris" do
    expect(Bolt::SSH).to receive(:new).with('a.net', any_args)
    expect(Bolt::WinRM).to receive(:new).with('b.com', any_args)

    Bolt::Executor.from_uris(['ssh://a.net', 'winrm://b.com'])
  end
end
