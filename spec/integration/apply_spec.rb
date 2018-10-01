# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/run'

describe "apply" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Run

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--format json --nodes #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:tflags) { %W[--no-host-key-check --run-as root --sudo-password #{password}] }

    def root_config
      { 'modulepath' => File.join(__dir__, '../fixtures/apply'),
        'ssh' => {
          'run-as' => 'root',
          'sudo-password' => conn_info('ssh')[:password],
          'host-key-check' => false
        } }
    end

    after(:all) do
      # TODO: Extract into test helper if needed in more files
      uri = conn_uri('ssh')
      inventory_data = conn_inventory
      config_data = root_config
      uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
      run_command(uninstall, uri, config: config_data, inventory: inventory_data)
    end

    context "when installing puppet" do
      before(:each) do
        uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
        run_cli_json(%W[command run #{uninstall}] + config_flags)
      end

      it 'succeeds when run twice' do
        result = run_cli_json(%w[plan run prep] + config_flags)
        expect(result).not_to include('kind')
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        report = result[0]['result']['report']
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_info('ssh')[:host]}]")

        result = run_cli_json(%w[plan run prep] + config_flags)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        report = result[0]['result']['report']
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_info('ssh')[:host]}]")
      end
    end

    context "with a puppet_agent installed" do
      before(:all) do
        # TODO: Extract into test helper if needed in more files
        uri = conn_uri('ssh')
        inventory_data = conn_inventory
        config_data = root_config
        run_task('puppet_agent::install', uri, config: config_data, inventory: inventory_data)
      end

      it 'errors when there are resource failures' do
        result = run_cli_json(%w[plan run basic::failure] + config_flags, rescue_exec: true)
        expect(result).to include('kind' => 'bolt/apply-failure')
        error = result['details']['result_set'][0]['result']['_error']
        expect(error['kind']).to eq('bolt/resource-failure')
        expect(error['msg']).to match(/Resources failed to apply/)
      end

      it 'applies a notify and ignores local settings' do
        run_command('echo environment=doesnotexist > /etc/puppetlabs/puppet/puppet.conf',
                    uri, config: root_config, inventory: conn_inventory)

        result = run_cli_json(%w[plan run basic::class] + config_flags)
        expect(result).not_to include('kind')
        expect(result[0]).to include('status' => 'success')
        expect(result[0]['result']['_output']).to eq('changed: 1, failed: 0, unchanged: 0 skipped: 0, noop: 0')
        resources = result[0]['result']['report']['resource_statuses']
        expect(resources).to include('Notify[hello world]')
      end
    end
  end
end
