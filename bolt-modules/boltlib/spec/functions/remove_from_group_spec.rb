# frozen_string_literal: true

describe 'remove_from_group' do
  include PuppetlabsSpec::Fixtures
  let(:executor)      { Bolt::Executor.new }
  let(:config)        { Bolt::Config.default }
  let(:pal)           { nil }
  let(:plugins)       { Bolt::Plugin.setup(config, pal) }
  let(:inventory)     { Bolt::Inventory.create_version(data, config.transport, config.transports, plugins) }
  let(:tasks_enabled) { true }
  let(:target1)       { 'target1' }
  let(:target2)       { 'target2' }
  let(:parent)        { 'group1' }
  let(:child)         { 'group2' }

  let(:data) do
    { 'groups' => [
      { 'name' => parent,
        'targets' => [target1],
        'groups' => [
          { 'name' => child,
            'targets' => [target1, target2] }
        ] }
    ] }
  end

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target1, 1)
                      .and_raise_error(ArgumentError,
                                       "'remove_from_group' parameter 'group' expects a String value, got Integer")
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('remove_from_group')
    is_expected.to run.with_params(target1, parent)
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that remove_from_group is not available' do
      is_expected.to run.with_params(target1, parent)
                        .and_raise_error(/Plan language function 'remove_from_group' cannot be used/)
    end
  end

  context 'removing target from a group' do
    it 'errors when removing multiple targets' do
      is_expected.to run.with_params(%w[foo bar], 'group1')
                        .and_raise_error(Bolt::Inventory::ValidationError,
                                         "'remove_from_group' expects a single Target, got 2")
    end

    it "errors when removing targets from 'all' group" do
      is_expected.to run.with_params(target1, 'all')
                        .and_raise_error(Bolt::Inventory::ValidationError,
                                         "Cannot remove Target from Group 'all'")
    end

    it 'removes target from the specified group' do
      is_expected.to run.with_params(target1, child)
      targets = inventory.get_targets(child).map(&:name)
      expect(targets).not_to include(target1)
    end

    it 'removes target from child groups' do
      is_expected.to run.with_params(target1, parent)
      targets = inventory.get_targets(child).map(&:name)
      expect(targets).not_to include(target1)
    end

    it 'removes target from parent groups' do
      is_expected.to run.with_params(target2, child)
      targets = inventory.get_targets(parent).map(&:name)
      expect(targets).not_to include(target2)
    end

    it 'does not remove targets from parent groups that also define the target' do
      is_expected.to run.with_params(target1, child)
      targets = inventory.get_targets(parent).map(&:name)
      expect(targets).to include(target1)
    end
  end
end
