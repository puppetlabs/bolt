require 'spec_helper'

module Bolt
  class MockCallback
    attr_reader :results

    def call(target, result)
      @results = [target, result]
    end
  end
end

describe "Bolt::Notifier" do
  let(:executor) { Concurrent::ImmediateExecutor.new }
  let(:target) { Bolt::Target.new('node1') }
  let(:success) { Bolt::Result.new(target) }
  let(:callback) { Bolt::MockCallback.new }
  let(:notifier) { Bolt::Notifier.new(executor) }

  it "notifies the caller" do
    notifier.notify(callback, target, success)

    expect(callback.results).to eq([target, success])
  end

  it "shuts down the executor and waits for pending tasks to finish" do
    notifier.notify(callback, target, success)

    expect(executor).to receive(:shutdown)
    expect(executor).to receive(:wait_for_termination)

    notifier.shutdown
  end
end
