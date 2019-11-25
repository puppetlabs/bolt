# frozen_string_literal: true

require 'spec_helper'
require 'bolt/analytics'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/plugin'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'
require 'bolt/task'

describe 'apply_prep' do
  include PuppetlabsSpec::Fixtures
  let(:applicator) { mock('Bolt::Applicator') }
  let(:executor) { Bolt::Executor.new(1, Bolt::Analytics::NoopClient.new) }
  let(:plugins) { Bolt::Plugin.setup(Bolt::Config.default, nil, nil, Bolt::Analytics::NoopClient.new) }
  let(:plugin_result) { {} }
  let(:task_hook) { proc { |_opts, target, _fun| proc { Bolt::Result.new(target, value: plugin_result) } } }
  let(:inventory) { Bolt::Inventory.create_version({}, nil, plugins) }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    executor.stubs(:noop).returns(false)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory, apply_executor: applicator) do
      example.run
    end
  end

  context 'with targets' do
    let(:hostnames) { %w[a.b.com winrm://x.y.com pcp://foo] }
    let(:targets) { hostnames.map { |h| Bolt::Target.new(h) } }
    let(:unknown_targets) { targets.reject { |target| target.protocol == 'pcp' } }
    let(:fact) { { 'osfamily' => 'none' } }
    let(:custom_facts_task) { Bolt::Task.new(name: 'custom_facts_task') }
    let(:version_task) { Bolt::Task.new(name: 'puppet_agent::version') }
    let(:install_task) { Bolt::Task.new(name: 'puppet_agent::install') }
    let(:service_task) { Bolt::Task.new(name: 'service') }

    before(:each) do
      applicator.stubs(:build_plugin_tarball).returns(:tarball)
      applicator.stubs(:custom_facts_task).returns(custom_facts_task)
      inventory.get_targets(targets)
      targets.each { |t| inventory.set_feature(t, 'puppet-agent', false) }

      task1 = mock('version_task')
      task1.stubs(:task_hash).returns(name: 'puppet_agent::version')
      task1.stubs(:runnable_with?).returns(true)
      Puppet::Pal::ScriptCompiler.any_instance.stubs(:task_signature).with('puppet_agent::version').returns(task1)
      task2 = mock('install_task')
      task2.stubs(:task_hash).returns(name: 'puppet_agent::install')
      task2.stubs(:runnable_with?).returns(true)
      Puppet::Pal::ScriptCompiler.any_instance.stubs(:task_signature).with('puppet_agent::install').returns(task2)
      task3 = mock('service_task')
      task3.stubs(:task_hash).returns(name: 'service')
      task3.stubs(:runnable_with?).returns(true)
      Puppet::Pal::ScriptCompiler.any_instance.stubs(:task_signature).with('service').returns(task3)
    end

    it 'sets feature and gathers facts' do
      versions = Bolt::ResultSet.new(unknown_targets.map { |t| Bolt::Result.new(t, value: { 'version' => '5.0.0' }) })
      executor.expects(:run_task).with(unknown_targets, version_task, anything, anything).returns(versions)

      facts = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: fact) })
      executor.expects(:run_task).with(targets, custom_facts_task, includes('plugins')).returns(facts)

      is_expected.to run.with_params(hostnames.join(',')).and_return(nil)
      targets.each do |target|
        expect(inventory.features(target)).to include('puppet-agent') unless target.transport == 'pcp'
        expect(inventory.facts(target)).to eq(fact)
      end
    end

    it 'installs the agent if not present' do
      versions = Bolt::ResultSet.new(
        unknown_targets.zip(['yes', nil]).map { |t, v| Bolt::Result.new(t, value: { 'version' => v }) }
      )
      executor.expects(:run_task).with(unknown_targets, version_task, anything, anything).returns(versions)

      facts = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: fact) })
      executor.expects(:run_task).with(targets, custom_facts_task, includes('plugins')).returns(facts)

      plugins.expects(:get_hook)
             .with("puppet_agent", :puppet_library)
             .returns(task_hook)

      is_expected.to run.with_params(hostnames)
      targets.each do |target|
        expect(inventory.features(target)).to include('puppet-agent') unless target.transport == 'pcp'
        expect(inventory.facts(target)).to eq(fact)
      end
    end

    it 'fails if version task is not found' do
      Puppet::Pal::ScriptCompiler.any_instance.expects(:task_signature).with('puppet_agent::version')
      is_expected.to run.with_params(hostnames).and_raise_error(
        Bolt::Error, "Task 'puppet_agent::version' could not be found"
      )
    end

    it 'fails if version check fails' do
      failed_results = Bolt::ResultSet.new(
        unknown_targets.map { |t| Bolt::Result.new(t, error: { 'msg' => 'could not get version' }) }
      )
      executor.expects(:run_task).with(unknown_targets, version_task, anything, anything).returns(failed_results)

      is_expected.to run.with_params(hostnames).and_raise_error(
        Bolt::RunFailure, "Plan aborted: run_task 'puppet_agent::version' failed on 2 targets"
      )
    end

    it 'fails if fact gathering fails' do
      versions = Bolt::ResultSet.new(unknown_targets.map { |t| Bolt::Result.new(t, value: { 'version' => '5.0.0' }) })
      executor.expects(:run_task).with(unknown_targets, version_task, anything, anything).returns(versions)

      results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, error: { 'msg' => 'could not gather facts' }) }
      )
      executor.expects(:run_task).with(targets, custom_facts_task, includes('plugins')).returns(results)

      is_expected.to run.with_params(hostnames).and_raise_error(
        Bolt::RunFailure, "Plan aborted: run_task 'custom_facts_task' failed on #{targets.count} targets"
      )
    end

    context 'with configured plugin' do
      let(:hostname) { 'agentless' }
      let(:data) {
        {
          'nodes' => [{
            'name' => hostname,
            'plugin_hooks' => {
              'puppet_library' => {
                'plugin' => 'task',
                'task' => 'puppet_agent::install'
              }
            }
          }]
        }
      }
      let(:inventory) { Bolt::Inventory.create_version(data, nil, plugins) }
      let(:target) { inventory.get_targets(hostname)[0] }

      it 'installs the agent if not present' do
        version = Bolt::ResultSet.new([Bolt::Result.new(target, value: { 'version' => nil })])
        executor.expects(:run_task).with([target], version_task, anything, anything).returns(version)

        facts = Bolt::ResultSet.new([Bolt::Result.new(target, value: fact)])
        executor.expects(:run_task).with([target], custom_facts_task, includes('plugins')).returns(facts)

        plugins.expects(:get_hook)
               .with("task", :puppet_library)
               .returns(task_hook)

        is_expected.to run.with_params(hostname)
        expect(inventory.features(target)).to include('puppet-agent')
        expect(inventory.facts(target)).to eq(fact)
      end
    end

    context 'with default plugin inventory v2' do
      let(:hostname) { 'agentless' }
      let(:data) {
        {
          'version' => 2,
          'targets' => [{ 'uri' => hostname }]
        }
      }

      let(:config) { Bolt::Config.new(Bolt::Boltdir.new('.'), {}) }
      let(:pal) { nil }
      let(:plugins) { Bolt::Plugin.setup(config, pal, nil, Bolt::Analytics::NoopClient.new) }
      let(:inventory) { Bolt::Inventory.create_version(data, config, plugins) }
      let(:target) { inventory.get_target(hostname) }
      let(:targets) { inventory.get_targets(hostname) }

      it 'installs the agent if not present' do
        version = Bolt::ResultSet.new([Bolt::Result.new(target, value: { 'version' => nil })])
        executor.expects(:run_task).with([target], version_task, anything, anything).returns(version)

        facts = Bolt::ResultSet.new([Bolt::Result.new(target, value: fact)])
        executor.expects(:run_task).with([target], custom_facts_task, includes('plugins')).returns(facts)

        plugins.expects(:get_hook)
               .with('puppet_agent', :puppet_library)
               .returns(task_hook)

        is_expected.to run.with_params(hostname)
        expect(inventory.features(target)).to include('puppet-agent')
        expect(inventory.facts(target)).to eq(fact)
      end
    end
  end

  context 'with only pcp targets' do
    let(:hostnames) { %w[pcp://foo pcp://bar] }
    let(:targets) { hostnames.map { |h| Bolt::Target.new(h) } }
    let(:fact) { { 'osfamily' => 'none' } }
    let(:custom_facts_task) { Bolt::Task.new(name: 'custom_facts_task') }

    before(:each) do
      applicator.stubs(:build_plugin_tarball).returns(:tarball)
      applicator.stubs(:custom_facts_task).returns(custom_facts_task)
    end

    it 'sets feature and gathers facts' do
      facts = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: fact) })
      executor.expects(:run_task).with(targets, custom_facts_task, includes('plugins')).returns(facts)

      is_expected.to run.with_params(hostnames.join(',')).and_return(nil)
      targets.each do |target|
        expect(inventory.features(target)).to include('puppet-agent') unless target.transport == 'pcp'
        expect(inventory.facts(target)).to eq(fact)
      end
    end
  end

  context 'with targets assigned the puppet-agent feature' do
    let(:hostnames) { %w[foo bar] }
    let(:targets) { hostnames.map { |h| Bolt::Target.new(h) } }
    let(:fact) { { 'osfamily' => 'none' } }
    let(:custom_facts_task) { Bolt::Task.new(name: 'custom_facts_task') }

    before(:each) do
      applicator.stubs(:build_plugin_tarball).returns(:tarball)
      applicator.stubs(:custom_facts_task).returns(custom_facts_task)
      targets.each { |target| inventory.set_feature(target, 'puppet-agent') }
    end

    it 'sets feature and gathers facts' do
      facts = Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: fact) })
      executor.expects(:run_task).with(targets, custom_facts_task, includes('plugins')).returns(facts)

      is_expected.to run.with_params(hostnames.join(',')).and_return(nil)
      targets.each do |target|
        expect(inventory.features(target)).to include('puppet-agent')
        expect(inventory.facts(target)).to eq(fact)
      end
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that apply_prep is not available' do
      is_expected.to run.with_params('foo')
                        .and_raise_error(/Plan language function 'apply_prep' cannot be used/)
    end
  end
end
