# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'aggregate::targets' do
  include BoltSpec::Plans

  it 'collects targets with the same value' do
    expect_task('test_task').return_for_targets('target1' => { 'key1' => 'val', 'key2' => 'val' },
                                                'target2' => { 'key1' => 'val1', 'key2' => 'val' })
    result = run_plan('aggregate::targets', 'targets' => 'target1,target2', 'task' => 'test_task')
    expect(result.value).to eq('key1' => { 'val' => ['target1'], 'val1' => ['target2'] },
                               'key2' => { 'val' => %w[target1 target2] })
  end

  it 'passes params' do
    params = { 'param1' => 'pv', '_run_as' => 'me' }
    expect_task('test_task').always_return({}).with_params(params)
    result = run_plan('aggregate::targets', 'targets' => 'foo',
                                          'task' => 'test_task',
                                          'params' => params)
    expect(result.value).to eq({})
  end
end
