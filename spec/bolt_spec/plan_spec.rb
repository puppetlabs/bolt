# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe "BoltSpec::Plans" do
  include BoltSpec::Plans

  def modulepath
    File.join(__dir__, '../fixtures/bolt_spec')
  end

  it 'prints notice' do
    result = run_plan('plans', {})
    expect(result.value).to eq(nil)
  end

  context 'with tasks' do
    before(:each) do
      allow_task('plans::prep')
    end

    it 'runs' do
      expect_task('plans::foo').with_params('arg1' => true).always_return('status' => 'done')
      result = run_plan('plans::task', 'nodes' => 'foo,bar')
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
    end

    it 'returns different values' do
      expect_task('plans::foo').return_for_targets({
        'foo' => { 'status' => 'done' },
        'bar' => { 'status' => 'running' }
      })
      result = run_plan('plans::task', 'nodes' => 'foo,bar')
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      results = result.value.result_hash
      expect(results['foo']['status']).to eq('done')
      expect(results['bar']['status']).to eq('running')
    end
  end
end
