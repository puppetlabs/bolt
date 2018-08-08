# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/integration'
require 'bolt_spec/run'
require 'bolt/cli'

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
      result = run_plan('facts', { "nodes" => 'ssh' }, config: config_data, inventory: inventory)

      expect(result['value'].size).to eq(1)
      data = result['value'][0]

      expect(data['status']).to eq('success')
      expect(data['result'].size).to eq(1)
      expect(data['result']['os']['name']).to be
      expect(data['result']['os']['family']).to match(/RedHat|Debian/)
      expect(data['result']['os']['release']).to be
    end
  end

  describe 'over winrm', winrm: true do
    it 'gathers os facts' do
      result = run_plan('facts', { "nodes" => 'winrm' }, config: config_data, inventory: inventory)

      expect(result['value'].size).to eq(1)
      data = result['value'][0]

      expect(data['status']).to eq('success')
      expect(data['result'].size).to eq(1)
      expect(data['result']['os']['name']).to eq('windows')
      expect(data['result']['os']['family']).to eq('windows')
      expect(data['result']['os']['release']).to be
    end
  end
end
