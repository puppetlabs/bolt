# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'canary' do
  include BoltSpec::Plans

  it 'runs targets in two groups' do
    expect_task('test_task').be_called_times(2).always_return({})
    run_plan('canary', 'nodes' => 'foo,bar,baz', 'task' => 'test_task')
  end

  it 'skips targets after a failure' do
    allow_task('test_task').be_called_times(1).error_with('kind' => 'task-failed', 'msg' => 'oops')
    result = run_plan('canary', 'nodes' => 'foo,bar,baz', 'task' => 'test_task')
    kinds = result.value.map { |r| r.error_hash['kind'] }.sort
    expect(kinds).to eq(["canary/skipped-node", "canary/skipped-node", "task-failed"])
  end
end
