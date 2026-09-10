# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plan_result'
require 'bolt/error'

describe Bolt::PlanResult do
  describe '#initialize' do
    it 'sets value and status' do
      result = described_class.new({ 'key' => 'val' }, 'success')
      expect(result.value).to eq('key' => 'val')
      expect(result.status).to eq('success')
    end
  end

  describe '#ok?' do
    it 'returns true when status is success' do
      result = described_class.new(nil, 'success')
      expect(result.ok?).to be true
    end

    it 'returns false when status is failure' do
      result = described_class.new(nil, 'failure')
      expect(result.ok?).to be false
    end
  end

  describe '#==' do
    it 'returns true when value and status are equal' do
      a = described_class.new('hello', 'success')
      b = described_class.new('hello', 'success')
      expect(a).to eq(b)
    end

    it 'returns false when value differs' do
      a = described_class.new('hello', 'success')
      b = described_class.new('world', 'success')
      expect(a).not_to eq(b)
    end

    it 'returns false when status differs' do
      a = described_class.new('hello', 'success')
      b = described_class.new('hello', 'failure')
      expect(a).not_to eq(b)
    end
  end

  describe '#to_json' do
    it 'serializes the value to JSON' do
      result = described_class.new({ 'key' => 'val' }, 'success')
      parsed = JSON.parse(result.to_json)
      expect(parsed['key']).to eq('val')
    end

    it 'handles nil value' do
      result = described_class.new(nil, 'success')
      expect(result.to_json).to eq('null')
    end
  end

  describe '#to_s' do
    it 'returns the JSON representation' do
      result = described_class.new('hello', 'success')
      expect(result.to_s).to eq('"hello"')
    end
  end
end
