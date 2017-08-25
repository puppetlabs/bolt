require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:command) { "hostname" }
  let(:script) { '/path/to/script.sh' }
  let(:success) { Bolt::Success.new }

  def mock_node(name)
    node = double(name)
    allow(node).to receive(:connect)
    allow(node).to receive(:disconnect)
    node
  end

  it "executes a command on all nodes" do
    node1 = mock_node 'node1'
    expect(node1).to receive(:execute).with(command).and_return(success)
    node2 = mock_node 'node2'
    expect(node2).to receive(:execute).with(command).and_return(success)

    Bolt::Executor.new([node1, node2]).execute(command)
  end

  it "runs a script on all nodes" do
    node1 = mock_node 'node1'
    expect(node1).to receive(:run_script).with(script).and_return(success)
    node2 = mock_node 'node2'
    expect(node2).to receive(:run_script).with(script).and_return(success)

    results = Bolt::Executor.new([node1, node2]).run_script(script)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::Success)
    end
  end

  it "returns an exception result if the command raises" do
    logger = double('logger', error: nil)
    node = mock_node 'node'
    allow(node).to receive(:logger).and_return(logger)
    expect(node).to receive(:execute).with(command).and_raise("reset")

    results = Bolt::Executor.new([node]).execute(command)
    results.each_pair do |_, result|
      expect(result).to be_instance_of(Bolt::ExceptionFailure)
    end
  end
end
