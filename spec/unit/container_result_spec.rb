# frozen_string_literal: true

require 'spec_helper'
require 'bolt/container_result'

describe Bolt::ContainerResult do
  describe '.from_exception' do
    it 'creates a ContainerResult with an error from an exception' do
      ex = RuntimeError.new('connection refused')
      result = described_class.from_exception(ex, 1, 'myimage:latest')
      expect(result.ok?).to be false
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/container-error')
      expect(result['_error']['msg']).to match(/myimage:latest/)
      expect(result['_error']['msg']).to match(/connection refused/)
    end

    it 'includes exit_code in the error details' do
      ex = RuntimeError.new('oops')
      result = described_class.from_exception(ex, 42, 'alpine')
      expect(result['_error']['details']['exit_code']).to eq(42)
    end

    it 'includes position in details when provided' do
      ex = RuntimeError.new('oops')
      result = described_class.from_exception(ex, 1, 'alpine', position: ['/my/plan.pp', 7])
      expect(result['_error']['details']['file']).to eq('/my/plan.pp')
      expect(result['_error']['details']['line']).to eq(7)
    end
  end

  describe '#_pcore_init_hash' do
    it 'returns a hash with value and object' do
      result = described_class.new({ 'stdout' => 'hi' }, object: 'myimage')
      h = result._pcore_init_hash
      expect(h['value']).to eq('stdout' => 'hi')
    end
  end

  describe '#initialize' do
    it 'defaults value to empty hash when nil is passed' do
      result = described_class.new(nil)
      expect(result.value).to eq({})
    end

    it 'sets value and object' do
      result = described_class.new({ 'stdout' => 'hello' }, object: 'busybox')
      expect(result.value).to eq('stdout' => 'hello')
      expect(result.object).to eq('busybox')
    end
  end

  describe '#eql?' do
    it 'returns true for results with the same value' do
      a = described_class.new({ 'stdout' => 'hi' })
      b = described_class.new({ 'stdout' => 'hi' })
      expect(a).to eq(b)
    end

    it 'returns false for results with different values' do
      a = described_class.new({ 'stdout' => 'hi' })
      b = described_class.new({ 'stdout' => 'bye' })
      expect(a).not_to eq(b)
    end

    it 'returns false for results of different classes' do
      a = described_class.new({ 'stdout' => 'hi' })
      expect(a).not_to eq(Object.new)
    end
  end

  describe '#[]' do
    it 'provides hash-style access to the value' do
      result = described_class.new({ 'stdout' => 'hello', '_error' => nil })
      expect(result['stdout']).to eq('hello')
    end
  end

  describe '#to_json / #to_s' do
    it 'returns a JSON string' do
      result = described_class.new({ 'stdout' => 'hello' }, object: 'myimage')
      parsed = JSON.parse(result.to_json)
      expect(parsed['object']).to eq('myimage')
      expect(parsed['status']).to eq('success')
    end

    it 'to_s is an alias for to_json' do
      result = described_class.new({ 'stdout' => 'hi' })
      expect(result.to_s).to eq(result.to_json)
    end
  end

  describe '#safe_value' do
    it 'returns value when all strings are valid UTF-8' do
      result = described_class.new({ 'stdout' => 'hello' })
      expect(result.safe_value).to eq('stdout' => 'hello')
    end

    it 'replaces invalid bytes with hex codes' do
      bad = "\xFF\xFE".dup.force_encoding('UTF-8')
      result = described_class.new({ 'stdout' => bad })
      safe = result.safe_value
      expect(safe['stdout']).to match(/\\x/)
    end
  end

  describe '#stdout' do
    it 'returns the stdout value' do
      result = described_class.new({ 'stdout' => 'output' })
      expect(result.stdout).to eq('output')
    end

    it 'returns nil when stdout is not set' do
      result = described_class.new({})
      expect(result.stdout).to be_nil
    end
  end

  describe '#stderr' do
    it 'returns the stderr value' do
      result = described_class.new({ 'stderr' => 'error output' })
      expect(result.stderr).to eq('error output')
    end
  end

  describe '#to_data' do
    it 'returns a hash with object, status, and value' do
      result = described_class.new({ 'stdout' => 'hi' }, object: 'busybox')
      data = result.to_data
      expect(data['object']).to eq('busybox')
      expect(data['status']).to eq('success')
      expect(data['value']).to eq('stdout' => 'hi')
    end
  end

  describe '#status' do
    it 'returns success when ok' do
      result = described_class.new({ 'stdout' => 'hi' })
      expect(result.status).to eq('success')
    end

    it 'returns failure when not ok' do
      result = described_class.new({ '_error' => { 'kind' => 'some-error', 'msg' => 'oops', 'details' => {} } })
      expect(result.status).to eq('failure')
    end
  end

  describe '#ok?' do
    it 'returns true when there is no error' do
      result = described_class.new({ 'stdout' => 'hi' })
      expect(result.ok?).to be true
      expect(result.ok).to be true
      expect(result.success?).to be true
    end

    it 'returns false when there is an error' do
      result = described_class.new({ '_error' => { 'kind' => 'err', 'msg' => 'oops', 'details' => {} } })
      expect(result.ok?).to be false
    end
  end

  describe '#error_hash' do
    it 'returns nil when no error' do
      result = described_class.new({ 'stdout' => 'hi' })
      expect(result.error_hash).to be_nil
    end

    it 'returns the error hash when present' do
      error = { 'kind' => 'some-error', 'msg' => 'oops', 'details' => {} }
      result = described_class.new({ '_error' => error })
      expect(result.error_hash).to eq(error)
    end
  end
end
