# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

# Expect targets, plan_name, return_expects to be set.
# Expect expect_action to be defined.
shared_examples 'action tests' do
  it 'runs' do
    expect_action.always_return('status' => 'done')
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).to be_ok
    expect(result.value.class).to eq(Bolt::ResultSet)
    results = result.value.result_hash
    targets.each { |target| expect(results[target]['status']).to eq('done') }
  end

  it 'returns different values' do
    expect_action.return_for_targets(
      targets[0] => { 'status' => 'done' },
      targets[1] => { 'status' => 'running' }
    )
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).to be_ok
    expect(result.value.class).to eq(Bolt::ResultSet)
    results = result.value.result_hash
    expect(results[targets[0]]['status']).to eq('done')
    expect(results[targets[1]]['status']).to eq('running')
  end

  it 'returns from a block' do
    expect_action.return do |targets:, **kwargs|
      Bolt::ResultSet.new(targets.map { |targ| Bolt::Result.new(targ, value: kwargs) })
    end
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).to be_ok
    expect(result.value.class).to eq(Bolt::ResultSet)
    results = result.value.result_hash
    targets.each do |target|
      expect(results[target].value).to eq(return_expects)
    end
  end

  it 'errors' do
    expect_action.error_with('kind' => 'mine', 'msg' => 'failed')
    result = run_plan(plan_name, 'nodes' => targets)
    expect(result).not_to be_ok
  end
end

describe "BoltSpec::Plans" do
  include BoltSpec::Plans

  def modulepath
    File.join(__dir__, '../fixtures/bolt_spec')
  end

  let(:targets) { %w[foo bar] }

  it 'prints notice' do
    result = run_plan('plans', {})
    expect(result.value).to eq(nil)
  end

  context 'with commands' do
    let(:plan_name) { 'plans::command' }
    let(:return_expects) { { command: 'echo hello', params: {} } }

    before(:each) do
      allow_command('hostname').with_targets(targets)
    end

    def expect_action
      expect_command('echo hello').with_params({})
    end

    include_examples 'action tests'
  end

  context 'with scripts' do
    let(:plan_name) { 'plans::script' }
    let(:return_expects) { { script: 'plans/script', params: { 'arguments' => ['arg'] } } }

    before(:each) do
      allow_script('plans/dir/prep').with_targets(targets)
    end

    def expect_action
      expect_script('plans/script').with_params('arguments' => ['arg'])
    end

    include_examples 'action tests'
  end

  context 'with tasks' do
    let(:plan_name) { 'plans::task' }
    let(:return_expects) { { task: 'plans::foo', params: { 'arg1' => true } } }

    before(:each) do
      allow_task('plans::prep').with_targets(targets)
    end

    def expect_action
      expect_task('plans::foo').with_params('arg1' => true)
    end

    include_examples 'action tests'
  end

  context 'with uploads' do
    let(:plan_name) { 'plans::upload' }
    let(:return_expects) { { source: 'plans/script', destination: '/d', params: {} } }

    before(:each) do
      allow_upload('plans/dir/prep').with_targets(targets)
    end

    def expect_action
      expect_upload('plans/script').with_destination('/d').with_params({})
    end

    include_examples 'action tests'
  end
end
