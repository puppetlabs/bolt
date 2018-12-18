# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/target'
require 'bolt/task'

describe 'get_resources' do
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
    let(:hostnames) { %w[a.b.com winrm://x.y.com pcp://foo] }
    let(:targets) { hostnames.map { |h| Bolt::Target.new(h) } }
    let(:query_resources_task) { Bolt::Task.new(name: 'query_resources_task') }

    before(:each) do
      applicator.stubs(:build_plugin_tarball).returns(:tarball)
      applicator.stubs(:query_resources_task).returns(query_resources_task)
    end

    it 'queries a single resource' do
      results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, value: { 'some' => 'resources' }) }
      )
      executor.expects(:run_task).with(targets,
                                       query_resources_task,
                                       has_entry('resources', ['file'])).returns(results)

      is_expected.to run.with_params(hostnames, 'file').and_return(results)
    end

    it 'queries requested resources' do
      results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, value: { 'some' => 'resources' }) }
      )
      resources = ['User', 'File[/tmp]']
      executor.expects(:run_task).with(targets,
                                       query_resources_task,
                                       has_entry('resources', resources)).returns(results)

      is_expected.to run.with_params(hostnames, resources).and_return(results)
    end

    it 'fails if querying resources fails' do
      results = Bolt::ResultSet.new(
        targets.map { |t| Bolt::Result.new(t, error: { 'msg' => 'could not query resources' }) }
      )
      executor.expects(:run_task).with(targets, query_resources_task, includes('plugins')).returns(results)

      is_expected.to run.with_params(hostnames, []).and_raise_error(
        Bolt::RunFailure, "Plan aborted: run_task 'query_resources_task' failed on #{targets.count} nodes"
      )
    end

    it 'errors if resource names are invalid' do
      is_expected.to run.with_params(hostnames, 'not a type').and_raise_error(
        Bolt::Error, "not a type is not a valid resource type or type instance name"
      )
    end

    it 'errors if resource names are invalid' do
      is_expected.to run.with_params(hostnames, 'not a type[hello there]').and_raise_error(
        Bolt::Error, "not a type[hello there] is not a valid resource type or type instance name"
      )
    end
  end
end
