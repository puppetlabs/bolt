# frozen_string_literal: true

require 'plan_helper'

describe 'minifact::info' do
  include_context 'plan helper'

  describe "plan's return value" do
    it 'contains OS information for every target for which facts were retrieved successfully' do
      populate_mock_inventory(
        'ssh-host-1,winrm://winrm-host-1,local://host,ssh://ssh-host-2,pcp://pcp-host,winrm://winrm-host-2'
      )
      results = generate_results(inventory.protocol_targets('ssh', 'local', 'winrm', 'pcp')) { |target, index|
        if index % 2 == 0 # fail every other target # rubocop:disable Style/EvenOdd
          {
            '_error' => {
              'msg' => "Failed on #{target.name}"
            }
          }
        else
          family = target.protocol == 'winrm' ? 'windows' : 'unix'
          {
            'os' => {
              'name'    => family,
              'family'  => family,
              'release' => {}
            }
          }
        end
      }
      bash_results = results.select { |result| case result.target.protocol when 'ssh', 'local' then true; end }
      powershell_results = results.select { |result| case result.target.protocol when 'winrm' then true; end }
      ruby_results = results.select { |result| case result.target.protocol when 'pcp' then true; end }

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

      executor.expects(:run_task).with(
        inventory.protocol_targets('pcp'),
        responds_with(:name, 'minifact::ruby'),
        {},
        {}
      ).returns(Bolt::ResultSet.new(ruby_results))

      expected_result = results.each_with_object([]) do |result, accumulator|
        if result.ok
          accumulator << "#{result.target.name}: " \
            "#{result['os']['name']} #{result['os']['release']['full']} (#{result['os']['family']})"
        end
      end

      expect(run_subject_plan('nodes' => inventory.nodes).to_set).to eq(expected_result.to_set)
    end
  end
end
