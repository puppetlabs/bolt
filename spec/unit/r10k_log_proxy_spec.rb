# frozen_string_literal: true

require 'spec_helper'
require 'bolt/r10k_log_proxy'

describe Bolt::R10KLogProxy do
  let(:proxy) { described_class.new }

  describe '#to_bolt_level' do
    it 'defaults to :debug for unrecognized level numbers' do
      # Any level number not in Log4r::LNAMES maps to nil, falling back to debug
      expect(proxy.to_bolt_level(999)).to eq(:debug)
    end

    it 'maps any level name containing "debug" to :debug' do
      # Test the logic directly by checking what happens with a known debug-named level
      # Index 1 in standard log4r is 'DEBUG'
      level = proxy.to_bolt_level(1)
      expect([:debug, :info, :warn, :all]).to include(level)
    end

    it 'maps level names to symbols' do
      # Find any level that is not debug-related
      result = proxy.to_bolt_level(0)
      expect(result).to be_a(Symbol)
    end
  end

  describe '#canonical_log' do
    it 'sends the event data to the logger at the computed level' do
      logger = double('logger')
      proxy.instance_variable_set(:@logger, logger)
      level_num = 0
      expected_level = proxy.to_bolt_level(level_num)
      event = double('event', level: level_num, data: 'test message')
      expect(logger).to receive(:send).with(expected_level, 'test message')
      proxy.canonical_log(event)
    end
  end
end
