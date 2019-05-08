# frozen_string_literal: true

describe 'add_to_group' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.new({}) }
  let(:target) { Bolt::Target.new('example') }
  let(:group) { 'all' }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should add a target to group' do
    is_expected.to run.with_params(target, group)
    expect(inventory.get_targets('all')[0].name).to eq('example')
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target, 1)
                      .and_raise_error(ArgumentError,
                                       "'add_to_group' parameter 'group' expects a String value, got Integer")
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('add_to_group')
    is_expected.to run.with_params(target, group)
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that add_to_group is not available' do
      is_expected.to run.with_params(target, group)
                        .and_raise_error(/Plan language function 'add_to_group' cannot be used/)
    end
  end
end
