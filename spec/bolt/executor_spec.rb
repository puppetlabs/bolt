require 'spec_helper'
require 'bolt/executor'

describe "Bolt::Executor" do
  let(:command) { "hostname" }

  it "executes a command on all nodes" do
    node1 = double 'node1'
    expect(node1).to receive(:execute).with(command)
    node2 = double 'node2'
    expect(node2).to receive(:execute).with(command)

    Bolt::Executor.new([node1, node2]).execute(command)
  end
end
