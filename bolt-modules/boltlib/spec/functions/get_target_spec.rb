# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'get_target' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'with inventory' do
    let(:hostname) { 'foo.example.com ' }
    let(:target) { inventory.get_target(hostname) }
    let(:groupname) { 'all' }

    it 'with given uri' do
      is_expected.to run.with_params(hostname).and_return(target)
    end

    it 'with given Target' do
      is_expected.to run.with_params(target).and_return(target)
    end

    it 'with given Target in array' do
      is_expected.to run.with_params([target]).and_return(target)
    end

    it 'errors when anything but a single target is returned' do
      inventory.expects(:get_target).with(groupname).once.returns([anything, anything])

      is_expected.to run.with_params(groupname)
                        .and_raise_error(Puppet::Pops::Types::TypeAssertionError)
    end

    it 'errors on unknown types' do
      is_expected.to run.with_params(mock('anything')).and_raise_error(ArgumentError)
    end

    it 'reports the call to analytics' do
      executor.expects(:report_function_call).with('get_target')
      is_expected.to run.with_params(hostname).and_return(target)
    end
  end
end
