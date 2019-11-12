# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'
require 'bolt/result'
require 'bolt/result_set'

describe 'aggregate::targets' do
  def make_result(uri, value)
    target = Bolt::Target.new(uri)
    Bolt::Result.new(target, value: value)
  end

  it 'enumerates targets for two distinct values' do
    input = Bolt::ResultSet.new(%w[target1 target2].map { |u| make_result(u, 'value' => u) })
    expected = { 'value' => { 'target1' => %w[target1], 'target2' => %w[target2] } }

    is_expected.to run.with_params(input).and_return(expected)
  end

  it 'enumerates targets for two of the same value' do
    input = Bolt::ResultSet.new(%w[target1 target2].map { |u| make_result(u, 'value1' => true, 'value2' => false) })
    expected = { 'value1' => { 'true' => %w[target1 target2] }, 'value2' => { 'false' => %w[target1 target2] } }

    is_expected.to run.with_params(input).and_return(expected)
  end
end
