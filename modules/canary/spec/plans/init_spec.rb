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
    expect(result.value.kind).to(eq("bolt/run-failure"))
    expect(result.status).to(eq("failure"))
    kinds = result.value.details['result_set'].map { |r| r.error_hash['kind'] }.sort
    expect(kinds).to eq(["canary/skipped-node", "canary/skipped-node", "task-failed"])
  end

  it 'fails if a target fails' do
    expect_task('test_task').be_called_times(2).return do |opts|
      targets = opts[:targets]
      if targets.length == 1
        Bolt::ResultSet.new([Bolt::Result.new(targets[0], value: {})])
      else
        results = targets.map do |target|
          Bolt::Result.new(target, error: { 'msg' => "Error", 'kind' => "kind", 'details' => {} })
        end
        Bolt::ResultSet.new(results)
      end
    end
    result = run_plan('canary', 'nodes' => 'foo,bar,baz', 'task' => 'test_task')
    expect(result.status).to(eq("failure"))
  end
end
