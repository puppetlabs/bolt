# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'facts::retrieve' do
  include BoltSpec::Plans

  let(:node) { '' }
  let(:target) { Bolt::Target.new(node) }

  def fact_output(node_ = node)
    { 'fqdn' => node_ }
  end

  def err_output(node_ = node)
    { '_error' => { 'msg' => "Failed on #{node_}" } }
  end

  def results(output)
    Bolt::ResultSet.new([Bolt::Result.new(target, value: output)])
  end

  context 'an ssh target' do
    let(:node) { 'ssh://host' }

    it 'retrieves facts' do
      expect_task('facts::bash').always_return(fact_output)

      expect(run_plan('facts::retrieve', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::bash').always_return(err_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'a winrm target' do
    let(:node) { 'winrm://host' }

    it 'retrieves facts' do
      expect_task('facts::powershell').always_return(fact_output)

      expect(run_plan('facts::retrieve', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::powershell').always_return(err_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'a pcp target' do
    let(:node) { 'pcp://host' }

    it 'retrieves facts' do
      expect_task('facts::ruby').always_return(fact_output)

      expect(run_plan('facts::retrieve', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::ruby').always_return(err_output)

      expect(run_plan('facts', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'a local target' do
    let(:node) { 'local://' }

    it 'retrieves facts' do
      expect_task('facts::bash').always_return(fact_output)

      expect(run_plan('facts::retrieve', 'nodes' => [node])).to eq(results(fact_output))
    end

    it 'omits failed targets' do
      expect_task('facts::bash').always_return(err_output)

      expect(run_plan('facts::retrieve', 'nodes' => [node])).to eq(results(err_output))
    end
  end

  context 'ssh, winrm, and pcp targets' do
    let(:nodes) { %w[ssh://host1 winrm://host2 pcp://host3] }

    it 'contains OS information for target' do
      %w[facts::bash facts::powershell facts::ruby].zip(nodes).each do |task, node|
        expect_task(task).return_for_targets(node => fact_output(node))
      end

      result_set = Bolt::ResultSet.new(
        nodes.map { |node| Bolt::Result.new(Bolt::Target.new(node), value: fact_output(node)) }
      )
      expect(run_plan('facts::retrieve', 'nodes' => nodes)).to eq(result_set)
    end

    it 'omits failed targets' do
      %w[facts::bash facts::powershell facts::ruby].zip(nodes).each do |task, node|
        expect_task(task).return_for_targets(node => err_output(node))
      end

      result_set = Bolt::ResultSet.new(
        nodes.map { |node| Bolt::Result.new(Bolt::Target.new(node), value: err_output(node)) }
      )
      expect(run_plan('facts::retrieve', 'nodes' => nodes)).to eq(result_set)
    end
  end
end
