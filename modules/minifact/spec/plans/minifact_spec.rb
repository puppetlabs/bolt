# frozen_string_literal: true

require 'plan_helper'

describe 'minifact' do
  include_context 'plan helper'

  describe 'retrieved facts processing' do
    it 'stores the retrieved facts for every target for which they were retrieved successfully' do
      populate_mock_inventory(
        'ssh-host-1,winrm://winrm-host,local://host,ssh://ssh-host-2,pcp://pcp-host,unsupported://'
      )

      results = generate_results(inventory.protocol_targets('ssh', 'winrm', 'pcp')) { |target, index|
        if index % 3 == 0 # fail every third target
          {
            '_error' => {
              'msg' => "Failed on #{target.name}"
            }
          }
        else
          {
            '_output' => "Ran on #{target.name}"
          }
        end
      }

      results.each do |result|
        inventory.expects(:add_facts).with(result.target, result.value) if result.ok
      end

      Puppet::Util.stubs(:which).with('bash').returns(nil)

      executor.expects(:run_task).with(
        inventory.protocol_targets('ssh'),
        responds_with(:name, 'minifact::bash'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(results.select { |result| result.target.protocol == 'ssh' }))

      executor.expects(:run_task).with(
        inventory.protocol_targets('winrm'),
        responds_with(:name, 'minifact::powershell'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(results.select { |result| result.target.protocol == 'winrm' }))

      executor.expects(:run_task).with(
        inventory.protocol_targets('pcp'),
        responds_with(:name, 'minifact::ruby'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(results.select { |result| result.target.protocol == 'pcp' }))

      run_subject_plan('nodes' => inventory.nodes)
    end
  end

  describe "plan's return value" do
    it 'contains a result for each target' do
      populate_mock_inventory(
        'ssh-host-1,winrm://winrm-host,local://host,ssh://ssh-host-2,pcp://pcp-host,unsupported://'
      )

      bash_results = generate_results(inventory.protocol_targets('ssh', 'local')) { |target|
        {
          '_error' => {
            'msg' => "Failed on #{target.name}"
          }
        }
      }
      powershell_results = generate_results(inventory.protocol_targets('winrm'))
      ruby_results = generate_results(inventory.protocol_targets('pcp'))
      unsupported_results = generate_results(
        inventory.protocol_targets('ssh', 'local', 'winrm', 'pcp', inverse: true),
        error: {
          'kind' => 'minifact/unsupported',
          'msg'  => 'Target not supported by minifact.'
        }
      )

      Puppet::Util.stubs(:which).with('bash').returns('/bin/bash')
      inventory.stubs(:add_facts)

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

      executor.expects(:run_task).with(
        inventory.protocol_targets('pcp'),
        responds_with(:name, 'minifact::ruby'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(ruby_results))

      result = run_subject_plan('nodes' => inventory.nodes)

      expect(result.result_hash).to eq(
        Bolt::ResultSet.new(bash_results + powershell_results + ruby_results + unsupported_results).result_hash
      )
    end
  end
end
