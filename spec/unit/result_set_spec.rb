# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/result'
require 'bolt/target'

describe Bolt::Result do
  let(:target1) { "target1" }
  let(:target2) { "target1" }
  let(:result_val1) { { 'key' => 'val1' } }
  let(:result_val2) { { 'key' => 'val2', '_error' => { 'kind' => 'bolt/oops' } } }
  let(:result_set) do
    Bolt::ResultSet.new([
                          Bolt::Result.new(Bolt::Target.new(target1), value: result_val1),
                          Bolt::Result.new(Bolt::Target.new(target2), value: result_val2)
                        ])
  end
  let(:expected) {
    [{ "target" => "target1",
       "action" => 'action',
       "object" => nil,
       "status" => "success",
       "value" => { "key" => "val1" } },
     { "target" => "target1",
       "action" => 'action',
       "object" => nil,
       "status" => "failure",
       "value" => { "key" => "val2", "_error" => { "kind" => "bolt/oops" } } }]
  }

  it 'is enumerable' do
    expect(result_set.map { |r| r['key'] }).to eq(%w[val1 val2])
  end

  it 'to_json creates the correct json' do
    expect(JSON.parse(result_set.to_json)).to eq(expected)
  end

  it 'to_data exposes resultset as array of hashes' do
    expect(result_set.to_data).to eq(expected)
  end

  it 'filter_set returns a ResultSet' do
    expect(result_set.filter_set { |r| r['target'] == 'target1' }).to be_a(Bolt::ResultSet)
  end

  it 'is array indexible' do
    expect([0, 1].map { |i| result_set[i].target.name }).to eq([target1, target2])
  end

  it 'is array indexible with slice' do
    expect(result_set[0, 2].map { |result| result.target.name }).to eq([target1, target2])
  end

  describe '#count / #length / #size' do
    it 'returns the number of results' do
      expect(result_set.count).to eq(2)
      expect(result_set.length).to eq(2)
      expect(result_set.size).to eq(2)
    end
  end

  describe '#empty / #empty?' do
    it 'returns false when results are present' do
      expect(result_set.empty).to be false
      expect(result_set.empty?).to be false
    end

    it 'returns true when results are empty' do
      expect(Bolt::ResultSet.new([]).empty?).to be true
    end
  end

  describe '#targets' do
    it 'returns a list of targets' do
      targets = result_set.targets
      expect(targets.map(&:name)).to contain_exactly(target1, target2)
    end
  end

  describe '#names' do
    it 'returns a list of target names' do
      expect(result_set.names).to contain_exactly(target1, target2)
    end
  end

  describe '#ok / #ok?' do
    it 'returns false when any result failed' do
      expect(result_set.ok).to be false
      expect(result_set.ok?).to be false
    end

    it 'returns true when all results succeeded' do
      ok_set = Bolt::ResultSet.new([Bolt::Result.new(Bolt::Target.new(target1), value: result_val1)])
      expect(ok_set.ok).to be true
    end
  end

  describe '#error_set' do
    it 'returns a ResultSet with only failed results' do
      errors = result_set.error_set
      expect(errors).to be_a(Bolt::ResultSet)
      expect(errors.count).to eq(1)
      expect(errors.first['_error']).to include('kind' => 'bolt/oops')
    end
  end

  describe '#ok_set' do
    it 'returns a ResultSet with only successful results' do
      ok = result_set.ok_set
      expect(ok).to be_a(Bolt::ResultSet)
      expect(ok.count).to eq(1)
      expect(ok.first['key']).to eq('val1')
    end
  end

  describe '#find' do
    it 'returns a result for the given target name' do
      result = result_set.find(target1)
      expect(result).to be_a(Bolt::Result)
    end

    it 'returns nil when target is not found' do
      expect(result_set.find('nonexistent')).to be_nil
    end
  end

  describe '#first' do
    it 'returns the first result' do
      expect(result_set.first['key']).to eq('val1')
    end
  end

  describe '#eql?' do
    it 'returns true for equal result sets' do
      a = Bolt::ResultSet.new([Bolt::Result.new(Bolt::Target.new(target1), value: result_val1)])
      b = Bolt::ResultSet.new([Bolt::Result.new(Bolt::Target.new(target1), value: result_val1)])
      expect(a).to eq(b)
    end

    it 'returns false for different result sets' do
      a = Bolt::ResultSet.new([])
      expect(a).not_to eq(result_set)
    end
  end

  describe '#to_s' do
    it 'returns a JSON string' do
      expect(JSON.parse(result_set.to_s)).to be_an(Array)
    end
  end

  describe '#result_hash' do
    it 'maps target names to results' do
      h = result_set.result_hash
      expect(h[target1]).to be_a(Bolt::Result)
    end
  end

  describe '#_pcore_init_hash' do
    it 'returns hash with results key' do
      expect(result_set._pcore_init_hash).to eq('results' => result_set.results)
    end
  end

  describe '#_pcore_init_from_hash' do
    it 'initializes from a hash' do
      rs = Bolt::ResultSet.new([])
      rs._pcore_init_from_hash('results' => result_set.results)
      expect(rs.count).to eq(2)
    end
  end
end
