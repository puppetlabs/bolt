# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'aggregate::count' do
  include BoltSpec::Plans

  it 'counts the same value' do
    expect_task('test_task').always_return('key1' => 'val', 'key2' => 'val')
    result = run_plan('aggregate::count', 'targets' => 'foo,bar', 'task' => 'test_task')
    expect(result.value).to eq('key1' => { 'val' => 2 }, 'key2' => { 'val' => 2 })
  end

  it 'passes params' do
    params = { 'param1' => 'pv' }
    expect_task('test_task').always_return({}).with_params(params)
    result = run_plan('aggregate::count', 'targets' => 'foo',
                                          'task' => 'test_task',
                                          'params' => params)
    expect(result.value).to eq({})
  end
end
