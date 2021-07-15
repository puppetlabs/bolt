# frozen_string_literal: true

require 'spec_helper'
require 'bolt/fiber_executor'

describe "Bolt::FiberExecutor" do
  let(:fiber_executor)  { Bolt::FiberExecutor.new }
  let(:plan_id)         { 1234 }
  let(:mock_scope)      { double('scope', compiler: nil, to_hash: {}) }
  let(:mock_newscope)   { double('newscope', push_ephemerals: nil) }

  describe "#create_future" do
    it "creates a new scope if passed an existing scope" do
      expect(Puppet::Parser::Scope)
        .to receive(:new).and_return(mock_newscope)
      expect(Puppet::Parser::Scope::LocalScope)
        .to receive(:new).and_return({})

      fiber_executor.create_future(scope: mock_scope, plan_id: plan_id) { |_| return 0 }
    end

    it "does not create a new scope if an existing scope is not passed" do
      expect(Puppet::Parser::Scope)
        .not_to receive(:new)

      fiber_executor.create_future(plan_id: plan_id) { |_| return 0 }
    end

    it "creates a new PlanFuture object with a name" do
      expect(Bolt::PlanFuture).to receive(:new)
        .with(instance_of(Fiber), instance_of(Integer), name: 'name', plan_id: plan_id)
        .and_call_original
      fiber_executor.create_future(name: 'name', plan_id: plan_id) { |_| return 0 }
    end

    it "adds the PlanFuture to the list of futures" do
      fiber_executor.create_future(plan_id: plan_id) { |_| return 0 }
      expect(fiber_executor.active_futures.length).to eq(1)
      expect(fiber_executor.active_futures[0].class).to eq(Bolt::PlanFuture)
    end
  end

  describe "#round_robin" do
    before :each do
      @futures = %w[lion tiger bear].map do |val|
        fiber_executor.create_future(plan_id: plan_id) do
          sleep(rand(0.01..0.1))
          val + 's'
        end
      end
    end

    it "checks each fiber is alive twice per round_robin" do
      @futures.each do |future|
        expect(future).to receive(:alive?)
          .exactly(4).times
          .and_return(true, true, false, false)
      end

      fiber_executor.round_robin until fiber_executor.plan_complete?
    end

    it "resumes the fiber if it's still alive" do
      @futures.each do |future|
        # Return true once, then return false as many times as it's called
        allow(future).to receive(:alive?).and_return(true, false)
        expect(future).to receive(:resume)
      end

      fiber_executor.round_robin until fiber_executor.plan_complete?
    end

    it "removes PlanFutures from the FiberExecutor once it's done" do
      @futures.each do |future|
        # Return true once, then return false as many times as it's called
        allow(future).to receive(:alive?).and_return(true, false)
        expect(fiber_executor.active_futures).to receive(:delete)
          .with(future).and_call_original
      end

      fiber_executor.round_robin until fiber_executor.plan_complete?
      expect(fiber_executor.active_futures).to eq([])
    end

    it "sleeps if all futures returned immediately" do
      @futures.each do |future|
        # Return true once, then return false as many times as it's called
        allow(future).to receive(:alive?).and_return(true, true, false)
        allow(future).to receive(:resume).and_return(:returned_immediately, "Value")
      end

      expect(fiber_executor).to receive(:sleep)
      fiber_executor.round_robin until fiber_executor.plan_complete?
    end
  end

  describe "#wait" do
    context "when passed 'nil' futures" do
      before :each do
        h = { 'lion' => 2, 'tiger' => 2, 'bear' => 3 }
        @futures = h.map do |val, p_id|
          dbl = double("future_#{val}", value: val + 's', original_plan: p_id, fiber: nil)
          allow(dbl).to receive(:alive?).and_return(true, false)
          dbl
        end
        allow(fiber_executor).to receive(:all_futures).and_return(@futures)
        allow(fiber_executor).to receive(:wait).and_call_original
      end

      it "waits for all futures from the current plan invocation" do
        # Mock the plan ID
        expect(fiber_executor).to receive(:get_current_plan_id).and_return(2)

        # The actual thing we're testing - mock return to avoid yielding from
        # the root Fiber.
        expect(fiber_executor).to receive(:wait)
          .with(@futures[0..1], timeout: nil, catch_errors: false)

        fiber_executor.wait(nil)
      end

      it "returns results from all futures" do
        expect(fiber_executor).to receive(:get_current_plan_id).and_return(2)
        expect(fiber_executor.wait(nil)).to eq(%w[lions tigers])
      end

      it "continues getting futures until all futures have finished" do
        # Mock the plan ID
        expect(fiber_executor).to receive(:get_current_plan_id).and_return(2)

        # Assert that this loops
        expect(fiber_executor).to receive(:get_futures_for_plan)
          .with(plan_id: 2).twice
          .and_call_original

        fiber_executor.wait(nil)
      end
    end

    context "when passed a timeout" do
      before :each do
        @futures = %w[lion tiger bear].map do |val|
          name = "future_#{val}"
          error = Bolt::FutureTimeoutError.new(name, timeout)
          double(name, alive?: true, value: error, name: name)
        end
        allow(Fiber).to receive(:yield)
      end
      let(:timeout) { 0.1 }

      it "raises an error if any Futures exceed the timeout without catch_errors" do
        @futures.each do |f|
          # This is a little backwards since calling 'raise' should set the
          # value, not vice-versa, but it doesn't particularly matter for unit
          # testing.
          expect(f).to receive(:raise).with(f.value)
        end

        expect { fiber_executor.wait(@futures, timeout: timeout) }
          .to raise_error(Bolt::ParallelFailure, /parallel block failed on 3 targets/)
      end
    end

    context "when futures error" do
      before :each do
        @futures = %w[lion tiger bear].map do |val|
          name = "future_#{val}"
          error = Bolt::Error.new("Error", 'bolt/test-error')
          # Don't bother loading Puppet datatypes
          allow(error).to receive(:to_puppet_error).and_return(error)
          double(name, alive?: false, value: error, name: name)
        end
      end

      it "returns the result set if catch_errors is true" do
        expect { fiber_executor.wait(@futures, catch_errors: true) }.not_to raise_error
        expect(fiber_executor.wait(@futures, catch_errors: true))
          .to eq(@futures.map(&:value))
      end
    end
  end
end
