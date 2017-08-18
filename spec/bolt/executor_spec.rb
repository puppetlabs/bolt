require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:command) { "hostname" }

  def mock_node(name)
    node = double(name)
    allow(node).to receive(:connect)
    allow(node).to receive(:disconnect)
    node
  end

  it "executes a command on all nodes" do
    node1 = mock_node 'node1'
    expect(node1).to receive(:execute).with(command)
    allow(node1)
    node2 = mock_node 'node2'
    expect(node2).to receive(:execute).with(command)

    Bolt::Executor.new([node1, node2]).execute(command)
  end
end
