# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'facts::info' do
  include BoltSpec::Plans

  context 'an ssh target' do
    let(:node) { 'ssh://host' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'unix', 'family' => 'unix', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq(["#{node}: unix  (unix)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq([])
    end
  end

  context 'a winrm target' do
    let(:node) { 'winrm://host' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'win', 'family' => 'win', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq(["#{node}: win  (win)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq([])
    end
  end

  context 'a pcp target' do
    let(:node) { 'pcp://host' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'any', 'family' => 'any', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq(["#{node}: any  (any)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq([])
    end
  end

  context 'a local target' do
    let(:node) { 'local://' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'any', 'family' => 'any', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq(["#{node}: any  (any)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node]).value).to eq([])
    end
  end

  context 'ssh, winrm, and pcp targets' do
    let(:nodes) { %w[ssh://host1 winrm://host2 pcp://host3] }

    it 'contains OS information for target' do
      expect_task('facts').return_for_targets(
        nodes[0] => { 'os' => { 'name' => 'unix', 'family' => 'unix', 'release' => {} } },
        nodes[1] => { 'os' => { 'name' => 'win', 'family' => 'win', 'release' => {} } },
        nodes[2] => { 'os' => { 'name' => 'any', 'family' => 'any', 'release' => {} } }
      )

      expect(run_plan('facts::info', 'nodes' => nodes).value).to eq(
        ["#{nodes[0]}: unix  (unix)", "#{nodes[1]}: win  (win)", "#{nodes[2]}: any  (any)"]
      )
    end

    it 'omits failed targets' do
      target_results = nodes.each_with_object({}) do |node, h|
        h[node] = { '_error' => { 'msg' => "Failed on #{node}" } }
      end
      expect_task('facts').return_for_targets(target_results)

      expect(run_plan('facts::info', 'nodes' => nodes).value).to eq([])
    end
  end
end
