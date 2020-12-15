# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/run'

describe "running the facts plan" do
  include BoltSpec::Conn
  include BoltSpec::Run

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:config_data) {
    { "ssh" => { "host-key-check" => false },
      "winrm" => { "ssl" => false } }
  }
  let(:inventory) { conn_inventory }

  describe 'over ssh', ssh: true do
    it 'gathers os facts' do
      result = run_plan('facts', { "targets" => 'ssh' }, config: config_data, inventory: inventory)

      expect(result['value'].size).to eq(1)
      data = result['value'][0]

      expect(data['status']).to eq('success')
      expect(data['value']['os']['name']).to be
      expect(data['value']['os']['family']).to match(/RedHat|Debian/)
      expect(data['value']['os']['release']).to be
    end
  end

  describe 'over winrm', winrm: true do
    it 'gathers os facts' do
      result = run_plan('facts', { "targets" => 'winrm' }, config: config_data, inventory: inventory)

      expect(result['value'].size).to eq(1)
      data = result['value'][0]

      expect(data['status']).to eq('success')
      expect(data['value']['os']['name']).to eq('windows')
      expect(data['value']['os']['family']).to eq('windows')
      expect(data['value']['os']['release']).to be
    end
  end
end
