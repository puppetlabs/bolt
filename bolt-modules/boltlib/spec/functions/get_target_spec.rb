# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'get_target' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { mock('inventory') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      inventory.stubs(:version).returns(2)
      inventory.stubs(:target_implementation_class).returns(Bolt::Target2)
      example.run
    end
  end

  context 'with inventory v1' do
    it 'fails and reports that set_config is not available with inventory v1' do
      inventory.stubs(:version).returns(1)
      is_expected.to run
        .with_params('foo').and_raise_error(/Plan language function 'get_target' cannot be used/)
    end
  end

  context 'with inventory v2' do
    let(:hostname) { 'foo.example.com ' }
    let(:target) { Bolt::Target2.new(nil, hostname) }
    let(:groupname) { 'all' }

    it 'with given uri' do
      inventory.expects(:get_target).with(hostname).returns(target)

      is_expected.to run.with_params(hostname).and_return(target)
    end

    it 'with given Target' do
      inventory.expects(:get_target).with(target).returns(target)

      is_expected.to run.with_params(target).and_return(target)
    end

    it 'with given Target in array' do
      inventory.expects(:get_target).with([target]).returns(target)

      is_expected.to run.with_params([target]).and_return(target)
    end

    it 'errors when multiple targets returned' do
      inventory.expects(:get_target).with(groupname).returns([target, target])

      is_expected.to run.with_params(groupname)
                        .and_raise_error(Puppet::Pops::Types::TypeAssertionError)
    end

    it 'errors on unknown types' do
      is_expected.to run.with_params(mock('anything')).and_raise_error(ArgumentError)
    end

    it 'reports the call to analytics' do
      inventory.expects(:get_target).with(hostname).returns(target)
      executor.expects(:report_function_call).with('get_target')

      is_expected.to run.with_params(hostname).and_return(target)
    end
  end
end
