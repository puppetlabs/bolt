# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/run'

describe "devices" do
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

    let(:device_url) { "file:///tmp/#{SecureRandom.uuid}.json" }

    def root_config
      { 'modulepath' => File.join(__dir__, '../fixtures/apply'),
        'ssh' => {
          'run-as' => 'root',
          'sudo-password' => conn_info('ssh')[:password],
          'host-key-check' => false
        } }
    end

    def agent_version_inventory
      { 'groups' => [
        { 'name' => 'agent_targets',
          'groups' => [
            { 'name' => 'puppet_5',
              'nodes' => [conn_uri('ssh', override_port: 20023)],
              'config' => { 'ssh' => { 'port' => 20023 } } },
            { 'name' => 'puppet_6',
              'nodes' => [conn_uri('ssh', override_port: 20024)],
              'config' => { 'ssh' => { 'port' => 20024 } } }
          ],
          'config' => {
            'ssh' => { 'host' => conn_info('ssh')[:host],
                       'host-key-check' => false,
                       'user' => conn_info('ssh')[:user],
                       'password' => conn_info('ssh')[:password],
                       'key' => conn_info('ssh')[:key] }
          } },
      ] }
    end

    let(:device_inventory) do
      device_group = { 'name' => 'device_targets',
            'nodes' => [
              # TODO map name to url in target?
              { 'name' => 'p5_device',
                'url' => device_url,
                'device-type' => 'fake',
                'run-on' => 'puppet_5',
              },
              { 'name' => 'p6_device',
                'url' => device_url,
                'device-type' => 'fake',
                'run-on' => 'puppet_5',
              },
            ]
          }
      agent_version_inventory['groups'] << device_group
    end

    after(:all) do
      # TODO: Extract into test helper if needed in more files
      uri = conn_uri('ssh')
      inventory_data = conn_inventory
      config_data = root_config
      uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
      run_command(uninstall, uri, config: config_data, inventory: inventory_data)
    end

    context "when running against puppet 5 or puppet 6" do
      before(:all) do
        # install puppet5
        result = run_task('puppet_agent::install', 'puppet_5', { 'collection' => 'puppet5' },
                          config: root_config, inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')

        result = run_task('puppet_agent::version', 'puppet_5', inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        expect(result[0]['result']['version']).to match(/^5/)

        # install puppet6
        result = run_task('puppet_agent::install', 'puppet_6', { 'collection' => 'puppet6' },
                          config: root_config, inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')

        result = run_task('puppet_agent::version', 'puppet_6', inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        expect(result[0]['result']['version']).to match(/^6/)
      end

      it 'runs an apply plan' do
        with_tempfile_containing('inventory', YAML.dump(device_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[plan run device_test::facts --nodes device_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          require 'pry'; binding.pry
          results.each do |result|
            expect(result['status']).to eq('success')
            report = result['result']['report']
            expect(report['resource_statuses']).to include("Notify[Apply: Hi!]")
          end
        end
      end
    end
  end
end
