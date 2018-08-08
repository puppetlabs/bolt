# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "apply" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--format json --nodes #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:tflags) { %W[--no-host-key-check --run-as root --sudo-password #{password}] }

    after(:each) do
      uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
      run_cli_json(%W[command run #{uninstall}] + config_flags)
    end

    it 'installs puppet' do
      result = run_cli_json(%w[plan run prep] + config_flags)
      expect(result.count).to eq(1)
      expect(result[0]['status']).to eq('success')
      report = result[0]['result']
      expect(report['resource_statuses']).to include("Notify[Hello #{conn_info('ssh')[:host]}]")
    end

    it 'succeeds when run twice' do
      result = run_cli_json(%w[plan run prep] + config_flags)
      expect(result.count).to eq(1)
      expect(result[0]['status']).to eq('success')

      result = run_cli_json(%w[plan run prep] + config_flags)
      expect(result.count).to eq(1)
      expect(result[0]['status']).to eq('success')
      report = result[0]['result']
      expect(report['resource_statuses']).to include("Notify[Hello #{conn_info('ssh')[:host]}]")
    end
  end
end
