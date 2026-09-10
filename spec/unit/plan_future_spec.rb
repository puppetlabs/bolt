# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plan_future'

describe Bolt::PlanFuture do
  let(:future) { Bolt::PlanFuture.new(fiber, 'Test future', plan_id: 1234) }
  let(:fiber) { double('fiber', alive?: true) }

  describe '#original_plan' do
    it 'returns the last plan on the stack (the plan that created the future)' do
      expect(future.original_plan).to eq(1234)
    end
  end

  describe '#current_plan' do
    it 'returns the first plan on the stack (the innermost executing plan)' do
      expect(future.current_plan).to eq(1234)
    end
  end

  describe '#name' do
    it 'returns the explicit name when provided' do
      named = Bolt::PlanFuture.new(fiber, 'id-1', plan_id: 1, name: 'my_future')
      expect(named.name).to eq('my_future')
    end

    it 'returns the id when no explicit name is provided' do
      expect(future.name).to eq('Test future')
    end
  end

  describe '#to_s' do
    it 'includes the future name' do
      expect(future.to_s).to eq("Future 'Test future'")
    end
  end

  describe '#alive?' do
    it 'delegates to the fiber' do
      expect(fiber).to receive(:alive?).and_return(true)
      expect(future.alive?).to be true
    end
  end

  describe :resume do
    it "sets 'value' on the PlanFuture" do
      expect(fiber).to receive(:resume).and_return("Test value")
      future.resume
      expect(future.value).to eq("Test value")
    end

    it "returns the current value when fiber is not alive" do
      allow(fiber).to receive(:alive?).and_return(false)
      future.value = "stored value"
      expect(future.resume).to eq("stored value")
    end
  end

  describe :raise do
    it "sets 'value' to the error" do
      error = Bolt::Error.new('failed', 'my-exception')
      expect(fiber).to receive(:raise).with(error)
      future.raise(error)
      expect(future.value).to eq(error)
    end

    it "resumes a still-alive fiber via block when fiber.raise raises FiberError" do
      error = RuntimeError.new('kaboom')
      allow(fiber).to receive(:raise).and_raise(FiberError)
      allow(fiber).to receive(:alive?).and_return(true)
      expect(fiber).to receive(:resume)
      future.raise(error)
    end

    it "does not resume a dead fiber when fiber.raise raises FiberError" do
      error = RuntimeError.new('kaboom')
      allow(fiber).to receive(:raise).and_raise(FiberError)
      allow(fiber).to receive(:alive?).and_return(false)
      expect(fiber).not_to receive(:resume)
      future.raise(error)
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
