# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'set_config' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('example') }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that set_config is not available' do
      is_expected.to run
        .with_params(target, 'a', 'b').and_raise_error(/Plan language function 'set_config' cannot be used/)
    end
  end

  it 'should set a config on a target' do
    is_expected.to run.with_params(target, 'a', 'b').and_return(target)
    expect(target.config).to include('a' => 'b')
  end

  it 'should sets nested config on a target' do
    is_expected.to run.with_params(target, %w[a b], 'c').and_return(target)
    expect(target.config).to include('a' => { 'b' => 'c' })
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target, 1, 'one')
                      .and_raise_error(ArgumentError,
                                       /'set_config' parameter 'key_or_key_path' expects a value of type String/)
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('set_config')
    is_expected.to run.with_params(target, 'a', 'b').and_return(target)
  end
end
