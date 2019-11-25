# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/puppet_agent'
require 'bolt_spec/run'

describe "apply", expensive: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::PuppetAgent
  include BoltSpec::Run

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:hiera_config) { File.join(__dir__, '../fixtures/configs/empty.yml') }
  let(:config_flags) { %W[--format json --targets #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:user) { conn_info('winrm')[:user] }
    let(:password) { conn_info('ssh')[:password] }
    let(:tflags) { %W[--no-host-key-check --run-as root --sudo-password #{password}] }

    def root_config
      { 'modulepath' => File.join(__dir__, '../fixtures/apply') }
    end

    def agent_version_inventory
      inventory = docker_inventory(root: true)
      inventory['groups'] << {
        'name' => 'agent_targets',
        'groups' => [
          { 'name' => 'puppet_5',
            'targets' => ['puppet_5_node'] },
          { 'name' => 'puppet_6',
            'targets' => ['puppet_6_node'] }
        ]
      }
      inventory
    end

    def lib_plugin_inventory
      { 'version' => 2,
        'targets' => [{
          'uri' => conn_uri('ssh'),
          'plugin_hooks' => {
            'puppet_library' => {
              'plugin' => 'puppet_agent'
            }
          }
        }] }
    end

    def error_plugin_inventory
      { 'version' => 2,
        'targets' => [{
          'uri' => conn_uri('ssh'),
          'name' => 'error',
          'plugin_hooks' => {
            'puppet_library' => {
              'plugin' => 'task',
              'task' => 'prep::error'
            }
          }
        }, {
          'uri' => conn_uri('ssh'),
          'name' => 'success',
          'plugin_hooks' => {
            'puppet_library' => {
              'plugin' => 'install_agent'
            }
          }
        }, {
          # These fail the puppet_agent::version check if they're fake. Seems
          # like more effort than it's worth to mock them
          'uri' => conn_uri('ssh'),
          'name' => 'badparams',
          'plugin_hooks' => {
            'puppet_library' => {
              'plugin' => 'task',
              'task' => 'puppet_agent::install',
              'parameters' => {
                'collection' => 'The act or process of collecting.'
              }
            }
          }
        }, {
          'uri' => conn_uri('ssh'),
          'name' => 'badplugin',
          'plugin_hooks' => {
            'puppet_library' => {
              'plugin' => 'what plugin?'
            }
          }
        }] }
    end

    def task_plugin_inventory
      { 'version' => 2,
        'targets' => [{
          'uri' => conn_uri('ssh'),
          'plugin_hooks' => {
            'puppet_library' => {
              'plugin' => 'task',
              'task' => 'puppet_agent::install',
              'parameters' => { 'version' => '6.2.0' }
            }
          }
        }],
        'config' => root_config }
    end

    after(:all) do
      ssh_node = conn_uri('ssh', include_password: true)
      uninstall([ssh_node, 'agent_targets'], inventory: agent_version_inventory)
    end

    context "when running against puppet 5 or puppet 6" do
      before(:all) do
        # install puppet5
        install('puppet_5', collection: 'puppet5', inventory: agent_version_inventory)

        result = run_task('puppet_agent::version', 'puppet_5', {}, inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')
        expect(result[0]['result']['version']).to match(/^5/)

        # install puppet6
        result = run_task('puppet_agent::install', 'puppet_6', { 'collection' => 'puppet6' },
                          config: root_config, inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')

        result = run_task('puppet_agent::version', 'puppet_6', {}, inventory: agent_version_inventory)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')
        expect(result[0]['result']['version']).to match(/^6/)
      end

      it 'runs a ruby task' do
        with_tempfile_containing('inventory', YAML.dump(agent_version_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[task run basic::ruby_task --targets agent_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          results['items'].each do |result|
            expect(result['status']).to eq('success')
            expect(result['result']).to eq('ruby' => 'Hi')
          end
        end
      end

      it 'runs an apply plan' do
        with_tempfile_containing('inventory', YAML.dump(agent_version_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[plan run basic::notify --targets agent_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          results.each do |result|
            expect(result['status']).to eq('success')
            report = result['result']['report']
            expect(report['resource_statuses']).to include("Notify[Apply: Hi!]")
          end
        end
      end

      it 'succeeds with an empty hiera config' do
        with_tempfile_containing('bolt', YAML.dump("hiera-config" => hiera_config), '.yaml') do |conf|
          results = run_cli_json(%W[plan run prep --configfile #{conf.path}] + config_flags)
          results.each do |result|
            expect(result['status']).to eq('success')
            report = result['result']['report']
            expect(report['resource_statuses']).to include("Notify[Hello #{uri}]")
          end
        end
      end

      it 'gets resources' do
        with_tempfile_containing('inventory', YAML.dump(agent_version_inventory), '.yaml') do |inv|
          results = run_cli_json(%W[plan run basic::resources --targets agent_targets
                                    --modulepath #{modulepath} --inventoryfile #{inv.path}])
          results.each do |result|
            expect(result['status']).to eq('success')
            resources = result['result']['resources']
            expect(resources.map { |r| r['type'] }.uniq).to eq(%w[User File])
            expect(resources.select { |r| r['title'] == user && r['type'] == 'User' }.count).to eq(1)
            expect(resources.select { |r| r['title'] == '/tmp' && r['type'] == 'File' }.count).to eq(1)
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

      context 'with plugin configured' do
        let(:config_flags) { %W[--format json -n all --password #{password} --modulepath #{modulepath}] + tflags }
        let(:ssh_node) { conn_uri('ssh', include_password: true) }

        before(:each) do
          uninstall(ssh_node)
        end

        it 'with install_agent plugin configured installs the agent' do
          with_tempfile_containing('inventory', YAML.dump(lib_plugin_inventory), '.yaml') do |inv|
            result = run_cli_json(%W[plan run prep -i #{inv.path}] + config_flags)
            expect(result).not_to include('kind')
            expect(result.count).to eq(1)
            expect(result[0]['status']).to eq('success')
            report = result[0]['result']['report']
            expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")
          end
        end

        it 'errors appropriately per target' do
          with_tempfile_containing('inventory', YAML.dump(error_plugin_inventory), '.yaml') do |inv|
            result = run_cli_json(%W[plan run prep -i #{inv.path}] + config_flags)
            expect(result['kind']).to eq('bolt/run-failure')
            expect(result['msg']).to eq("Plan aborted: apply_prep failed on 3 targets")

            result_set = result['details']['result_set']
            task_error = result_set.select { |h| h['node'] == 'error' }[0]['result']['_error']
            expect(task_error['kind']).to eq('puppetlabs.tasks/task-error')
            expect(task_error['msg']).to include("The task failed with exit code 1")

            param_error = result_set.select { |h| h['node'] == 'badparams' }[0]['result']['_error']
            expect(param_error['kind']).to eq('bolt/plugin-error')
            expect(param_error['msg']).to include("Invalid parameters for Task puppet_agent::install")

            plugin_error = result_set.select { |h| h['node'] == 'badplugin' }[0]['result']['_error']
            expect(plugin_error['kind']).to eq('bolt/unknown-plugin')
            expect(plugin_error['msg']).to include("Unknown plugin: 'what plugin?'")
          end
        end

        it 'with task plugin configured installs the agent' do
          with_tempfile_containing('inventory', YAML.dump(task_plugin_inventory), '.yaml') do |inv|
            result = run_cli_json(%W[plan run prep -i #{inv.path}] + config_flags)
            expect(result).not_to include('kind')
            expect(result.count).to eq(1)
            expect(result[0]['status']).to eq('success')
            report = result[0]['result']['report']
            expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")
            result = run_cli_json(%W[task run puppet_agent::version -i #{inv.path}] + config_flags)['items']
            expect(result.count).to eq(1)
            expect(result[0]).to include('status' => 'success')
            expect(result[0]['result']['version']).to match(/^6\.2/)
          end
        end
      end

      it 'succeeds when run twice' do
        result = run_cli_json(%w[plan run prep] + config_flags)
        expect(result).not_to include('kind')
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        report = result[0]['result']['report']
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")

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
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")
      end
    end

    context "with a puppet_agent installed" do
      before(:all) do
        # Deferred must use puppet >= 6
        target = 'puppet_6'
        install(target, inventory: agent_version_inventory)
        result = run_task('puppet_agent::version', target, {}, config: root_config, inventory: agent_version_inventory)
        major_version = result.first['result']['version'].split('.').first.to_i
        expect(major_version).to be >= 6
      end

      context "apply() function" do
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

        it 'respects _run_as on a plan invocation' do
          user = conn_info('ssh')[:user]
          logs = run_cli_json(%W[plan run basic::run_as_apply user=#{user}] + config_flags)
          expect(logs.first['message']).to eq(conn_info('ssh')[:user])
        end
      end

      context "bolt apply command" do
        it "applies a manifest" do
          with_tempfile_containing('manifest', 'include basic', '.pp') do |manifest|
            results = run_cli_json(['apply', manifest.path] + config_flags)
            result = results[0]['result']
            expect(result).not_to include('kind')
            expect(result['report']).to include('status' => 'changed')
            expect(result['report']['resource_statuses']).to include('Notify[hello world]')
          end
        end

        it "applies with noop" do
          with_tempfile_containing('manifest', 'include basic', '.pp') do |manifest|
            results = run_cli_json(['apply', manifest.path, '--noop'] + config_flags)
            result = results[0]['result']
            expect(result).not_to include('kind')
            expect(result['report']).to include('status' => 'unchanged', 'noop' => true)
            expect(result['report']['resource_statuses']).to include('Notify[hello world]')
          end
        end

        it "applies a snippet of code" do
          results = run_cli_json(['apply', '-e', 'include basic'] + config_flags)
          result = results[0]['result']
          expect(result).not_to include('kind')
          expect(result['report']).to include('status' => 'changed')
          expect(result['report']['resource_statuses']).to include('Notify[hello world]')
        end

        it "fails if the manifest doesn't parse" do
          expect { run_cli_json(['apply', '-e', 'include(basic'] + config_flags) }
            .to raise_error(/Syntax error/)
        end

        it "fails if the manifest doesn't compile" do
          results = run_cli_json(['apply', '-e', 'include shmasic'] + config_flags)
          result = results[0]['result']
          expect(result).to include('_error')
          expect(result['_error']['kind']).to eq('bolt/apply-error')
          expect(result['_error']['msg']).to match(/failed to compile/)
        end
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

        result = run_task('puppet_agent::version', conn_uri('winrm'), {}, config: config)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')
        expect(result[0]['result']['version']).to match(/^5/)
      end

      it 'runs a ruby task' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[task run basic::ruby_task --targets #{uri}
                                    --configfile #{conf.path}])
          results['items'].each do |result|
            expect(result).to include('status' => 'success')
            expect(result['result']).to eq('ruby' => 'Hi')
          end
        end
      end

      it 'runs an apply plan' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[plan run basic::notify --targets #{uri}
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
        expect(result[0]).to include('status' => 'success')

        result = run_task('puppet_agent::version', conn_uri('winrm'), {}, config: config)
        expect(result.count).to eq(1)
        expect(result[0]).to include('status' => 'success')
        expect(result[0]['result']['version']).to match(/^6/)
      end

      it 'runs a ruby task' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[task run basic::ruby_task --targets #{uri}
                                    --configfile #{conf.path}])
          results['items'].each do |result|
            expect(result).to include('status' => 'success')
            expect(result['result']).to eq('ruby' => 'Hi')
          end
        end
      end

      it 'runs an apply plan' do
        with_tempfile_containing('bolt', YAML.dump(config), '.yaml') do |conf|
          results = run_cli_json(%W[plan run basic::notify --targets #{uri}
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
