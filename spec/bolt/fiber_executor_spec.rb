# frozen_string_literal: true

require 'spec_helper'
require 'bolt/fiber_executor'

describe "Bolt::FiberExecutor" do
  let(:fiber_executor)  { Bolt::FiberExecutor.new }
  let(:mock_scope)      { double('scope', compiler: nil, to_hash: {}) }
  let(:mock_newscope)   { double('newscope', push_ephemerals: nil) }

  describe "#create_future" do
    it "creates a new scope if passed an existing scope" do
      expect(Puppet::Parser::Scope)
        .to receive(:new).and_return(mock_newscope)
      expect(Puppet::Parser::Scope::LocalScope)
        .to receive(:new).and_return({})

      fiber_executor.create_future(scope: mock_scope) { |_| return 0 }
    end

    it "does not create a new scope if an existing scope is not passed" do
      expect(Puppet::Parser::Scope)
        .not_to receive(:new)

      fiber_executor.create_future { |_| return 0 }
    end

    it "creates a new PlanFuture object with a name" do
      expect(Bolt::PlanFuture).to receive(:new)
        .with(instance_of(Fiber), instance_of(Integer), 'name')
        .and_call_original
      fiber_executor.create_future(name: 'name') { |_| return 0 }
    end

    it "adds the PlanFuture to the list of futures" do
      fiber_executor.create_future { |_| return 0 }
      expect(fiber_executor.plan_futures.length).to eq(1)
      expect(fiber_executor.plan_futures[0].class).to eq(Bolt::PlanFuture)
    end
  end

  describe "#round_robin" do
    before :each do
      @futures = %w[lion tiger bear].map do |val|
        fiber_executor.create_future do
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
        expect(fiber_executor.plan_futures).to receive(:delete)
          .with(future).and_call_original
      end

      fiber_executor.round_robin until fiber_executor.plan_complete?
      expect(fiber_executor.plan_futures).to eq([])
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
end
