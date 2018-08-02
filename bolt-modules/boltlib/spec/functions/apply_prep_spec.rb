# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'

describe 'apply_prep' do
  include PuppetlabsSpec::Fixtures
  let(:applicator) { mock('Bolt::Applicator') }
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.new({}) }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    executor.stubs(:noop).returns(false)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory, apply_executor: applicator) do
      example.run
    end
  end

  context 'with targets' do
    let(:hostnames) { %w[a.b.com x.y.com] }
    let(:targets) { hostnames.map { |h| Bolt::Target.new(h) } }
    let(:fact) { { 'osfamily' => 'none' } }
    let(:custom_facts_task) { mock('custom_facts_task') }

    before(:each) do
      applicator.stubs(:build_plugin_tarball).returns(:tarball)
      applicator.stubs(:custom_facts_task).returns(custom_facts_task)
      custom_facts_task.stubs(:name).returns('custom_facts_task')

      task1 = mock('version_task')
      task1.stubs(:name).returns('puppet_agent::version')
      task1.stubs(:task).returns(:version_task)
      Puppet::Pal::ScriptCompiler.any_instance.stubs(:task_signature).with('puppet_agent::version').returns(task1)
      task2 = mock('install_task')
      task2.stubs(:name).returns('puppet_agent::install')
      task2.stubs(:task).returns(:install_task)
      Puppet::Pal::ScriptCompiler.any_instance.stubs(:task_signature).with('puppet_agent::install').returns(task2)
    end

    it 'sets feature and gathers facts' do
      versions = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: { 'version' => '5.0.0' }) })
      executor.expects(:run_task).with(targets, :version_task, anything, anything).returns(versions)

      facts = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: fact) })
      executor.expects(:run_task).with(targets, custom_facts_task, 'plugins' => :tarball).returns(facts)

      is_expected.to run.with_params(hostnames.join(',')).and_return(nil)
      targets.each do |target|
        expect(inventory.features(target)).to include('puppet-agent')
        expect(inventory.facts(target)).to eq(fact)
      end
    end

    it 'installs the agent if not present' do
      versions = Bolt::ResultSet.new(
        targets.zip(['yes', nil]).map { |t, v| Bolt::Result.new(t, value: { 'version' => v }) }
      )
      executor.expects(:run_task).with(targets, :version_task, anything, anything).returns(versions)
      ok_result = Bolt::ResultSet.new([])
      executor.expects(:run_task).with(targets[1..1], :install_task, anything, anything).returns(ok_result)

      facts = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: fact) })
      executor.expects(:run_task).with(targets, custom_facts_task, 'plugins' => :tarball).returns(facts)

      is_expected.to run.with_params(hostnames)
      targets.each do |target|
        expect(inventory.features(target)).to include('puppet-agent')
        expect(inventory.facts(target)).to eq(fact)
      end
    end

    it 'fails if version check fails' do
      failed_results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, error: { 'msg' => 'could not get version' }) }
      )
      executor.expects(:run_task).with(targets, :version_task, anything, anything).returns(failed_results)

      is_expected.to run.with_params(hostnames).and_raise_error(
        Bolt::RunFailure, "Plan aborted: run_task 'puppet_agent::version' failed on 2 nodes"
      )
    end

    it 'fails if install fails' do
      versions = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: {}) })
      executor.expects(:run_task).with(targets, :version_task, anything, anything).returns(versions)

      failed_results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, error: { 'msg' => 'could not install package' }) }
      )
      executor.expects(:run_task).with(targets, :install_task, anything, anything).returns(failed_results)

      is_expected.to run.with_params(hostnames).and_raise_error(
        Bolt::RunFailure, "Plan aborted: run_task 'puppet_agent::install' failed on 2 nodes"
      )
    end

    it 'fails if fact gathering fails' do
      versions = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: { 'version' => '5.0.0' }) })
      executor.expects(:run_task).with(targets, :version_task, anything, anything).returns(versions)

      results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, error: { 'msg' => 'could not gather facts' }) }
      )
      executor.expects(:run_task).with(targets, custom_facts_task, 'plugins' => :tarball).returns(results)

      is_expected.to run.with_params(hostnames).and_raise_error(
        Bolt::RunFailure, "Plan aborted: run_task 'custom_facts_task' failed on 2 nodes"
      )
    end
  end
end
