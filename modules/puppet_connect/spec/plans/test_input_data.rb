# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'
require 'bolt/target'

describe 'puppet_connect::test_input_data' do
  include BoltSpec::Plans

  let(:inventory_data) do
    {
      'version' => 2,
      'targets' => [
        {
          'name' => 'ssh_target',
          'uri'  => 'ssh_uri',
          'config' => {
            'transport' => 'ssh',
            'ssh'  => {
              'load-config' => true
            }
          }
        },
        {
          'name'   => 'winrm_target',
          'uri'    => 'winrm_uri',
          'config' => {
            'transport' => 'winrm'
          }
        }
      ]
    }
  end
  let(:ssh_target) { inventory.get_target('ssh_target') }
  let(:winrm_target) { inventory.get_target('winrm_target') }

  context 'when the inventory contains an unsupported Puppet Connect transport' do
    let(:inventory_data) do
      sup = super()
      sup['targets'].first['config']['transport'] = 'docker'
      sup
    end

    it 'returns an error result' do
      result = run_plan('puppet_connect::test_input_data', {})
      expect(result.ok?).to be(false)
      expect(result.value.msg).to match(%r{ssh_target.*ssh.*winrm})
    end
  end

  it 'sets load-config to false for ssh targets' do
    allow_command('echo Connected')
      .always_return({})

    winrm_config_before = winrm_target.config
    run_plan('puppet_connect::test_input_data', {})

    expect(ssh_target.config).to include('ssh' => { 'load-config' => false })
    expect(winrm_target.config).to eql(winrm_config_before)
  end

  it 'checks if the targets are connectable' do
    expect_command('echo Connected')
      .be_called_times(1)
      .with_targets(['ssh_target', 'winrm_target'])
      .return_for_targets({
        'ssh_target' => {
          'stdout' => 'Connected'
        },
        'winrm_target' => {
          'stdout' => 'Connected'
        }
      })

    result = run_plan('puppet_connect::test_input_data', {}).value
    expect(result.size).to eql(2)
    ssh_result = result.first
    winrm_result = result[1]
    expect(ssh_result.value).to include('stdout' => 'Connected')
    expect(winrm_result.value).to include('stdout' => 'Connected')
  end
end
