# frozen_string_literal: true

require 'spec_helper'
require 'bolt/error'

describe Bolt::Error do
  describe '#to_h' do
    it 'returns a hash with kind, msg, and details' do
      error = Bolt::Error.new('test message', 'bolt/test-error', { 'key' => 'value' })
      h = error.to_h
      expect(h['kind']).to eq('bolt/test-error')
      expect(h['msg']).to eq('test message')
      expect(h['details']).to eq({ 'key' => 'value' })
    end

    it 'includes issue_code when present' do
      error = Bolt::Error.new('msg', 'bolt/test', {}, 'ISSUE_1')
      expect(error.to_h['issue_code']).to eq('ISSUE_1')
    end
  end

  describe '#to_json' do
    it 'returns valid JSON' do
      error = Bolt::Error.new('msg', 'bolt/test', { 'a' => 1 })
      parsed = JSON.parse(error.to_json)
      expect(parsed['kind']).to eq('bolt/test')
      expect(parsed['msg']).to eq('msg')
    end
  end

  describe 'nested Error objects in details' do
    it 'flattens a nested Bolt::Error to a hash' do
      inner = Bolt::Error.new('inner message', 'bolt/inner-error', { 'inner_key' => 'inner_value' })
      outer = Bolt::Error.new('outer message', 'bolt/outer-error', { 'error' => inner })

      expect(outer.details['error']).to be_a(Hash)
      expect(outer.details['error']['kind']).to eq('bolt/inner-error')
      expect(outer.details['error']['msg']).to eq('inner message')
      expect(outer.details['error']['details']).to eq({ 'inner_key' => 'inner_value' })
    end

    it 'flattens deeply nested Bolt::Error objects' do
      innermost = Bolt::Error.new('deep', 'bolt/deep', {})
      middle = Bolt::Error.new('mid', 'bolt/mid', { 'cause' => innermost })
      outer = Bolt::Error.new('top', 'bolt/top', { 'wrapped' => middle })

      expect(outer.details['wrapped']).to be_a(Hash)
      expect(outer.details['wrapped']['details']['cause']).to be_a(Hash)
      expect(outer.details['wrapped']['details']['cause']['msg']).to eq('deep')
    end

    it 'flattens Bolt::Error inside an array in details' do
      inner = Bolt::Error.new('arr error', 'bolt/arr', {})
      outer = Bolt::Error.new('top', 'bolt/top', { 'errors' => [inner] })

      expect(outer.details['errors']).to be_an(Array)
      expect(outer.details['errors'][0]).to be_a(Hash)
      expect(outer.details['errors'][0]['msg']).to eq('arr error')
    end

    it 'serializes to JSON without infinite recursion' do
      inner = Bolt::Error.new('inner', 'bolt/inner', { 'x' => 1 })
      outer = Bolt::Error.new('outer', 'bolt/outer', { 'error' => inner })

      json = nil
      expect { json = outer.to_json }.not_to raise_error
      parsed = JSON.parse(json)
      expect(parsed['details']['error']['kind']).to eq('bolt/inner')
    end
  end
end
