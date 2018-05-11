# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "running the facts plan" do
  include BoltSpec::Config
  include BoltSpec::Conn
  include BoltSpec::Integration

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:user) { conn_info('ssh')[:user] }
    let(:password) { conn_info('ssh')[:password] }
    let(:config_flags) { %W[--nodes #{uri} --no-host-key-check --format json --password #{password}] }

    it 'gathers os facts' do
      result = run_cli_json(%w[plan run facts] + config_flags)
      expect(result.size).to eq(1)

      data = result[0]
      expect(data['node']).to eq(uri)
      expect(data['status']).to eq('success')
      expect(data['result'].size).to eq(1)
      expect(data['result']['os']['name']).to be
      # temporarily add Linux to matcher while BOLT-518 is investigated
      expect(data['result']['os']['family']).to match(/RedHat|Debian|Linux/)
      expect(data['result']['os']['release']).to be
    end
  end

  describe 'over winrm', winrm: true do
    let(:uri) { conn_uri('winrm') }
    let(:user) { conn_info('winrm')[:user] }
    let(:password) { conn_info('winrm')[:password] }
    let(:config_flags) { %W[--nodes #{uri} --no-ssl --format json --password #{password}] }

    it 'gathers os facts' do
      result = run_cli_json(%w[plan run facts] + config_flags)
      expect(result.size).to eq(1)

      data = result[0]
      expect(data['node']).to eq(uri)
      expect(data['status']).to eq('success')
      expect(data['result'].size).to eq(1)
      expect(data['result']['os']['name']).to eq('windows')
      expect(data['result']['os']['family']).to eq('windows')
      expect(data['result']['os']['release']).to be
    end
  end
end
