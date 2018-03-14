# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'
require 'bolt/result'
require 'bolt/result_set'

describe 'aggregate::count' do
  def make_result(uri, value)
    target = Bolt::Target.new(uri)
    Bolt::Result.new(target, value: value)
  end

  it 'counts two distinct values' do
    input = Bolt::ResultSet.new(%w[node1 node2].map { |u| make_result(u, 'value' => u) })
    expected = { 'value' => { 'node1' => 1, 'node2' => 1 } }

    is_expected.to run.with_params(input).and_return(expected)
  end

  it 'counts two of the same value' do
    input = Bolt::ResultSet.new(%w[node1 node2].map { |u| make_result(u, 'value1' => true, 'value2' => false) })
    expected = { 'value1' => { 'true' => 2 }, 'value2' => { 'false' => 2 } }

    is_expected.to run.with_params(input).and_return(expected)
  end
end
