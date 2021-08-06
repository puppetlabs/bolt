# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plan_future'

describe Bolt::PlanFuture do
  let(:future) { Bolt::PlanFuture.new(fiber, 'Test future', plan_id: 1234) }
  let(:fiber) { double('fiber', alive?: true) }

  describe :resume do
    it "sets 'value' on the PlanFuture" do
      expect(fiber).to receive(:resume).and_return("Test value")
      future.resume
      expect(future.value).to eq("Test value")
    end
  end

  describe :raise do
    it "sets 'value' to the error" do
      error = Bolt::Error.new('failed', 'my-exception')
      expect(fiber).to receive(:raise).with(error)
      future.raise(error)
      expect(future.value).to eq(error)
    end
  end

  describe :state do
    context 'when the Fiber is alive' do
      it "returns 'running' if the Fiber is still alive" do
        expect(future.state).to eq('running')
      end
    end

    context 'when the Fiber has exited and failed' do
      let(:fiber) { double('fiber', resume: RuntimeError.new('oops')) }

      before :each do
        allow(fiber).to receive(:alive?).and_return(true, false)
      end

      it "returns 'error' if the Fiber errored" do
        future.resume
        expect(future.state).to eq('error')
      end
    end

    context 'when the Fiber has exited and failed' do
      let(:fiber) { double('fiber', alive?: false, resume: 'Value') }

      it "returns 'done' if the Fiber exited successfully" do
        future.resume
        expect(future.state).to eq('done')
      end
    end
  end
end
