require 'spec_helper'

module Bolt
  class MockCallback
    attr_reader :results

    def call(node, result)
      @results = [node, result]
    end
  end
end

describe "Bolt::Notifier" do
  let(:executor) { Concurrent::ImmediateExecutor.new }
  let(:success) { Bolt::Node::Success.new }
  let(:callback) { Bolt::MockCallback.new }

  def mock_node(name)
    transport = double('holodeck')
    allow(transport).to receive(:initialize_transport)

    node = double(name, name: name)
    allow(node).to receive(:class).and_return(transport)
    allow(node).to receive(:connect)
    allow(node).to receive(:disconnect)
    node
  end

  it "notifies the caller" do
    node = mock_node('node1')
    notifier = Bolt::Notifier.new(executor)
    notifier.notify(callback, node, success)

    expect(callback.results).to eq([node, success])
  end

  it "shuts down the executor and waits for pending tasks to finish" do
    node = mock_node('node1')
    notifier = Bolt::Notifier.new(executor)
    notifier.notify(callback, node, success)

    expect(executor).to receive(:shutdown)
    expect(executor).to receive(:wait_for_termination)

    notifier.shutdown
  end
end
