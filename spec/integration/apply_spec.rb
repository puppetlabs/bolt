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
          } }
      ] }
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

      it 'runs a ruby task' do
        with_tempfile_containing('inventory', YAML.dump(agent_version_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[task run basic::ruby_task --nodes agent_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          results['items'].each do |result|
            expect(result['status']).to eq('success')
            expect(result['result']).to eq('ruby' => 'Hi')
          end
        end
      end

      it 'runs an apply plan' do
        with_tempfile_containing('inventory', YAML.dump(agent_version_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[plan run basic::notify --nodes agent_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          results.each do |result|
            expect(result['status']).to eq('success')
            report = result['result']['report']
            expect(report['resource_statuses']).to include("Notify[Apply: Hi!]")
          end
        end
      end

      it 'does not create Boltdir' do
        inventory_data = agent_version_inventory
        is_boltdir = "if [ -d ~/.puppetlabs ]; then echo 'exists'; else echo 'not found'; fi"
        results = run_command(is_boltdir, 'agent_targets', inventory: inventory_data)
        results.each do |result|
          expect(result['status']).to eq('success')
          expect(result['result']['stdout']).to match(/not found/)
        end
      end
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

        # Includes agent facts from apply_prep
        agent_facts = report['resource_statuses']['Notify[agent facts]']['events'][0]['desired_value'].split("\n")
        expect(agent_facts[0]).to match(/^\w+/)
        expect(agent_facts[1]).to eq(agent_facts[0])
        expect(agent_facts[2]).to match(/^\d+\.\d+\.\d+$/)
        expect(agent_facts[3]).to eq(agent_facts[2])
        expect(agent_facts[4]).to eq('false')

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
        run_task('puppet_agent::install', uri, { 'collection' => 'puppet6' }, config: config_data, inventory: inventory_data)
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

      it 'applies the deferred type' do
        result = run_cli_json(%w[plan run basic::defer] + config_flags)
        expect(result).not_to include('kind')
        expect(result[0]['status']).to eq('success')
        resources = result[0]['result']['report']['resource_statuses']
        local_pid = resources['Notify[local pid]']['events'][0]['desired_value'][/(\d+)/, 1]
        raise 'local pid was not found' if local_pid.nil?
        remote_pid = resources['Notify[remote pid]']['events'][0]['desired_value'][/(\d+)/, 1]
        raise 'remote pid was not found' if remote_pid.nil?
        expect(local_pid).not_to eq(remote_pid)
      end
    end
  end

  describe 'over winrm on Appveyor with Puppet Agents', appveyor_agents: true do
    let(:uri) { conn_uri('winrm') }
    let(:password) { conn_info('winrm')[:password] }
    let(:user) { conn_info('winrm')[:user] }

    def config
      { 'modulepath' => File.join(__dir__, '../fixtures/apply'),
        'winrm' => {
          'ssl' => false,
          'ssl-verify' => false,
          'user' => conn_info('winrm')[:user],
          'password' => conn_info('winrm')[:password]
        } }
    end

    context "when running against puppet 5" do
      before(:all) do
        result = run_task('puppet_agent::install', conn_uri('winrm'),
                          { 'collection' => 'puppet5' }, config: config)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')

        result = run_task('puppet_agent::version', conn_uri('winrm'), config: config)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        expect(result[0]['result']['version']).to match(/^5/)
      end

      it 'runs a ruby task' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[task run basic::ruby_task --nodes #{uri}
                                    --configfile #{conf.path}])
          results['items'].each do |result|
            expect(result).to include('status' => 'success')
            expect(result['result']).to eq('ruby' => 'Hi')
          end
        end
      end

      it 'runs an apply plan' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[plan run basic::notify --nodes #{uri}
                                    --configfile #{conf.path}])
          results.each do |result|
            expect(result).to include('status' => 'success')
            report = result['result']['report']
            expect(report['resource_statuses']).to include("Notify[Apply: Hi!]")
          end
        end
      end

      it 'does not create Boltdir' do
        is_boltdir = "if (!(Test-Path ~/.puppetlabs)) {echo 'not found'}"
        results = run_command(is_boltdir, conn_uri('winrm'), config: config)
        results.each do |result|
          expect(result).to include('status' => 'success')
          expect(result['result']['stdout']).to match(/not found/)
        end
      end
    end

    context "when running against puppet 6" do
      before(:all) do
        result = run_task('puppet_agent::install', conn_uri('winrm'),
                          { 'collection' => 'puppet6' }, config: config)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')

        result = run_task('puppet_agent::version', conn_uri('winrm'), config: config)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')
        expect(result[0]['result']['version']).to match(/^6/)
      end

      it 'runs a ruby task' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[task run basic::ruby_task --nodes #{uri}
                                    --configfile #{conf.path}])
          results['items'].each do |result|
            expect(result).to include('status' => 'success')
            expect(result['result']).to eq('ruby' => 'Hi')
          end
        end
      end

      it 'runs an apply plan' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[plan run basic::notify --nodes #{uri}
                                    --configfile #{conf.path}])
          results.each do |result|
            expect(result).to include('status' => 'success')
            report = result['result']['report']
            expect(report['resource_statuses']).to include("Notify[Apply: Hi!]")
          end
        end
      end

      it 'does not create Boltdir' do
        is_boltdir = "if (!(Test-Path ~/.puppetlabs)) {echo 'not found'}"
        results = run_command(is_boltdir, conn_uri('winrm'), config: config)
        results.each do |result|
          expect(result).to include('status' => 'success')
          expect(result['result']['stdout']).to match(/not found/)
        end
      end
    end
  end
end
