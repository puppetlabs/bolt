# frozen_string_literal: true

require 'plan_helper'

describe 'minifact::retrieve' do
  include_context 'plan helper'

  describe 'tasks run by the plan' do
    it 'runs the minifact::bash task on ssh:// targets' do
      populate_mock_inventory('host-1,ssh://host-2')

      executor.expects(:run_task).with(
        inventory.protocol_targets('ssh'),
        responds_with(:name, 'minifact::bash'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      run_subject_plan('nodes' => inventory.nodes)
    end

    it 'runs the minifact::bash task on the local:// target if bash is available' do
      populate_mock_inventory('local://host')

      Puppet::Util.expects(:which).with('bash').returns('/bin/bash')

      executor.expects(:run_task).with(
        inventory.protocol_targets('local'),
        responds_with(:name, 'minifact::bash'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      run_subject_plan('nodes' => inventory.nodes)
    end

    it 'runs the minifact::powershell task on winrm:// targets' do
      populate_mock_inventory('winrm://host-1,winrm://host-2')

      executor.expects(:run_task).with(
        inventory.protocol_targets('winrm'),
        responds_with(:name, 'minifact::powershell'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      run_subject_plan('nodes' => inventory.nodes)
    end

    it 'runs the minifact::ruby task on pcp:// targets' do
      populate_mock_inventory('pcp://host-1,pcp://host-2')

      executor.expects(:run_task).with(
        inventory.protocol_targets('pcp'),
        responds_with(:name, 'minifact::ruby'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      run_subject_plan('nodes' => inventory.nodes)
    end

    it "doesn't run any task on unsupported targets" do
      populate_mock_inventory('unsupported://host,local://host')

      Puppet::Util.expects(:which).with('bash').returns(nil)

      executor.expects(:run_task).never

      run_subject_plan('nodes' => inventory.nodes)
    end

    it 'runs multiple tasks as appropriate for the specified targets' do
      populate_mock_inventory(
        'ssh-host-1,winrm://winrm-host,pcp://pcp-host,local://host,ssh://ssh-host-2,unsupported://'
      )

      Puppet::Util.stubs(:which).with('bash').returns('/bin/bash')

      executor.expects(:run_task).with(
        inventory.protocol_targets('ssh', 'local'),
        responds_with(:name, 'minifact::bash'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      executor.expects(:run_task).with(
        inventory.protocol_targets('winrm'),
        responds_with(:name, 'minifact::powershell'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      executor.expects(:run_task).with(
        inventory.protocol_targets('pcp'),
        responds_with(:name, 'minifact::ruby'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      run_subject_plan('nodes' => inventory.nodes)
    end
  end

  describe "plan's return value" do
    it 'contains a result for each target' do
      populate_mock_inventory('ssh-host-1,winrm://winrm-host,local://host,ssh://ssh-host-2')
      bash_results = generate_results(inventory.protocol_targets('ssh', 'local'))
      powershell_results = generate_results(inventory.protocol_targets('winrm'))

      Puppet::Util.stubs(:which).with('bash').returns('/bin/bash')

      executor.expects(:run_task).with(
        inventory.protocol_targets('ssh', 'local'),
        responds_with(:name, 'minifact::bash'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(bash_results))

      executor.expects(:run_task).with(
        inventory.protocol_targets('winrm'),
        responds_with(:name, 'minifact::powershell'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(powershell_results))

      result = run_subject_plan('nodes' => inventory.nodes)

      expect(result.result_hash).to eq(Bolt::ResultSet.new(bash_results + powershell_results).result_hash)
    end

    it 'contains a synthesized error result for each unsupported target' do
      populate_mock_inventory(
        'ssh-host-1,winrm://winrm-host,local://host,ssh://ssh-host-2,pcp://pcp-host,unsupported://'
      )

      unsupported_results = generate_results(
        inventory.protocol_targets('ssh', 'winrm', 'pcp', inverse: true),
        error: {
          'kind' => 'minifact/unsupported',
          'msg'  => 'Target not supported by minifact.'
        }
      )

      Puppet::Util.stubs(:which).with('bash').returns(nil)

      executor.expects(:run_task).with(
        inventory.protocol_targets('ssh'),
        responds_with(:name, 'minifact::bash'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      executor.expects(:run_task).with(
        inventory.protocol_targets('winrm'),
        responds_with(:name, 'minifact::powershell'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      executor.expects(:run_task).with(
        inventory.protocol_targets('pcp'),
        responds_with(:name, 'minifact::ruby'),
        {},
        {}
      ).returns(Bolt::ResultSet.new([]))

      result = run_subject_plan('nodes' => inventory.nodes)

      expect(result.results).to eq(unsupported_results)
    end
  end
end
