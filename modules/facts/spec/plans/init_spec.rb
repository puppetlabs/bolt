# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'facts' do
  include BoltSpec::Plans

  let(:target) { Bolt::Target.new(node) }
  let(:fact_output) { { 'fqdn' => node } }
  let(:err_output) { { '_error' => { 'msg' => "Failed on #{node}" } } }

  def results(output)
    Bolt::ResultSet.new([Bolt::Result.new(target, value: output)])
  end

  context 'an ssh target' do
    let(:node) { 'ssh://host' }

    it 'adds facts to the Target' do
      expect_task('facts::bash').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::bash').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'a winrm target' do
    let(:node) { 'winrm://host' }

    it 'adds facts to the Target' do
      expect_task('facts::powershell').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::powershell').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'a pcp target' do
    let(:node) { 'pcp://host' }

    it 'adds facts to the Target' do
      expect_task('facts::ruby').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::ruby').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'a local target' do
    let(:node) { 'local://' }

    it 'reports unsupported if bash is absent' do
      Puppet::Util.stubs(:which).with('bash').returns(nil)
      err = { '_error' => { 'kind' => 'facts/unsupported', 'msg' => 'Target not supported by facts.' } }
      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err))
    end

    it 'adds facts to the Target' do
      Puppet::Util.stubs(:which).with('bash').returns('path')
      expect_task('facts::bash').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      Puppet::Util.stubs(:which).with('bash').returns('path')
      expect_task('facts::bash').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end
end
