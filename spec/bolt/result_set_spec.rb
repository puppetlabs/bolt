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
end
