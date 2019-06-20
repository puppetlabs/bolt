# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/puppet_agent'
require 'bolt_spec/run'

describe "devices" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::PuppetAgent
  include BoltSpec::Run

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--format json --nodes #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:tflags) { %W[--no-host-key-check --run-as root --sudo-password #{password}] }

    let(:device_path) { "/tmp/#{SecureRandom.uuid}.json" }

    def agent_version_inventory
      { 'groups' => [
        { 'name' => 'agent_targets',
          'nodes' => [
            { 'name' => "ssh://#{conn_info('ssh')[:host]}",
              'alias' => 'puppet_6',
              'config' => { 'ssh' => { 'port' => '20024' } } }
          ] }
      ],
        'config' => {
          'ssh' => { 'user' => 'root',
                     'host-key-check' => false,
                     'password' => root_password }
        } }
    end

    let(:device_inventory) do
      device_group = { 'name' => 'device_targets',
                       'nodes' => [
                         { 'name' => 'fake_device1',
                           'config' => {
                             'transport' => 'remote',
                             'remote' => {
                               'remote-transport' => 'fake',
                               'run-on' => 'puppet_6',
                               'path' => device_path
                             }
                           } }
                       ] }
      inv = agent_version_inventory
      inv['groups'] << device_group
      inv
    end

    after(:all) do
      uninstall('puppet_6', inventory: agent_version_inventory)
    end

    context "when running against puppet 6" do
      before(:all) do
        install('puppet_6', inventory: agent_version_inventory)
      end

      it 'runs a plan that collects facts' do
        with_tempfile_containing('inventory', YAML.dump(device_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[plan run device_test::facts --nodes device_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          expect(results).not_to include("kind")
          name, facts = results.first
          expect(name).to eq('fake_device1')
          expect(facts).to include("operatingsystem" => "FakeDevice",
                                   "exists" => false,
                                   "clientcert" => 'fake_device1')
        end
      end

      it 'runs a plan that applies resources' do
        with_tempfile_containing('inventory', YAML.dump(device_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[plan run device_test::set_a_val
                                    --nodes device_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          expect(results).not_to include("kind")

          report = results[0]['result']['report']
          expect(report['resource_statuses']).to include("Fake_device[key1]")

          content = run_command("cat '#{device_path}'", 'puppet_6', inventory: device_inventory)[0]['result']['stdout']
          expect(content).to eq({ key1: "val1" }.to_json)

          resources = run_cli_json(%W[plan run device_test::resources
                                      --nodes device_targets
                                      --modulepath #{modulepath} --inventoryfile #{inv.path}])
          expect(resources[0]['result']['resources'][0]).to eq("key1" =>
                                                               { "content" => "val1",
                                                                 "ensure" => "present",
                                                                 "merge" => false })
        end
      end
    end
  end
end
