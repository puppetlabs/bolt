# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'aggregate::nodes' do
  include BoltSpec::Plans

  it 'collects nodes with the same value' do
    expect_task('test_task').return_for_targets('node1' => { 'key1' => 'val', 'key2' => 'val' },
                                                'node2' => { 'key1' => 'val1', 'key2' => 'val' })
    result = run_plan('aggregate::nodes', 'nodes' => "node1,node2", "task" => "test_task")
    expect(result).to eq('key1' => { 'val' => ['node1'], 'val1' => ['node2'] }, 'key2' => { 'val' => %w[node1 node2] })
  end

  it 'passes params' do
    params = { "param1" => 'pv', '_run_as' => 'me' }
    expect_task('test_task').always_return({}).with_params(params)
    result = run_plan('aggregate::nodes', 'nodes' => "foo",
                                          "task" => "test_task",
                                          'params' => params)
    expect(result).to eq({})
  end
end
