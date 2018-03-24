# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'facts::info' do
  include BoltSpec::Plans

  context 'an ssh target' do
    let(:node) { 'ssh://host' }

    it 'contains OS information for target' do
      expect_task('facts::bash').always_return('os' => { 'name' => 'unix', 'family' => 'unix', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq(["#{node}: unix  (unix)"])
    end

    it 'omits failed targets' do
      expect_task('facts::bash').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq([])
    end
  end

  context 'a winrm target' do
    let(:node) { 'winrm://host' }

    it 'contains OS information for target' do
      expect_task('facts::powershell').always_return('os' => { 'name' => 'win', 'family' => 'win', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq(["#{node}: win  (win)"])
    end

    it 'omits failed targets' do
      expect_task('facts::powershell').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq([])
    end
  end

  context 'a pcp target' do
    let(:node) { 'pcp://host' }

    it 'contains OS information for target' do
      expect_task('facts::ruby').always_return('os' => { 'name' => 'any', 'family' => 'any', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq(["#{node}: any  (any)"])
    end

    it 'omits failed targets' do
      expect_task('facts::ruby').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq([])
    end
  end

  context 'a local target' do
    let(:node) { 'local://' }

    it 'omits the target if bash is absent' do
      Puppet::Util.stubs(:which).with('bash').returns(nil)
      expect(run_plan('facts::info', 'nodes' => [node])).to eq([])
    end

    it 'contains OS information for target' do
      Puppet::Util.stubs(:which).with('bash').returns('path')
      expect_task('facts::bash').always_return('os' => { 'name' => 'any', 'family' => 'any', 'release' => {} })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq(["#{node}: any  (any)"])
    end

    it 'omits failed targets' do
      Puppet::Util.stubs(:which).with('bash').returns('path')
      expect_task('facts::bash').always_return('_error' => { 'msg' => "Failed on #{node}" })

      expect(run_plan('facts::info', 'nodes' => [node])).to eq([])
    end
  end
end
