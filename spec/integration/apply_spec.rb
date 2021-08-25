# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'
require 'bolt_spec/puppet_agent'
require 'bolt_spec/run'

TEST_VERSIONS = [
  [6, 'puppet6'],
  [7, 'puppet']
].freeze

describe 'apply', expensive: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project
  include BoltSpec::PuppetAgent
  include BoltSpec::Run

  let(:apply_settings) { {} }
  let(:project)        { @project }
  let(:project_config) { base_config }

  let(:base_config) do
    {
      'apply-settings' => apply_settings,
      'hiera-config'   => fixtures_path('hiera', 'empty.yaml'),
      'modulepath'     => fixtures_path('apply')
    }
  end

  # The following are run with both *nix and Windows targets.
  shared_examples 'agentful tests' do |targets|
    it 'runs a ruby task' do
      results = run_cli_json(%W[task run basic::ruby_task -t #{targets}], project: project)

      results['items'].each do |result|
        expect(result).to include('status' => 'success')
        expect(result['value']).to eq('ruby' => 'Hi')
      end
    end

    it 'runs an apply plan' do
      results = run_cli_json(%W[plan run basic::notify -t #{targets}], project: project)

      results.each do |result|
        expect(result).to include('status' => 'success')
        expect(result.dig('value', 'report', 'resource_statuses')).to include("Notify[Apply: Hi!]")
      end
    end

    it 'succeeds with an empty hiera config' do
      results = run_cli_json(%W[plan run prep -t #{targets}], project: project)

      results.each do |result|
        expect(result['status']).to eq('success')
        expect(result.dig('value', 'report', 'resource_statuses')).to include(/Notify\[Hello .*\]/)
      end
    end

    it 'warns about exported resources with an ID' do
      allow(Bolt::Logger).to receive(:warn)
      expect(Bolt::Logger).to receive(:warn).with('exported_resources', /the export is ignored/).at_least(:once)
      expect(Bolt::Logger).to receive(:warn).with('exported_resources',
                                                  /the collection will be ignored/).at_least(:once)
      run_cli_json(%W[plan run basic::exported_resources -t #{targets}], project: project)
    end
  end

  describe 'over ssh', ssh: true do
    let(:uri)      { conn_uri('ssh') }
    let(:user)     { conn_info('ssh')[:user] }
    let(:password) { conn_info('ssh')[:password] }

    # Run tests that require the puppet-agent package to be installed on the target.
    # Each test is run against all agent targets unless otherwise noted.
    context 'with puppet installed' do
      # Set up a project directory for the tests. Include an inventory file so Bolt
      # can actually connect to the targets.
      around(:each) do |example|
        with_project(config: project_config, inventory: docker_inventory(root: true)) do |project|
          @project = project
          example.run
        end
      end

      # Run shared tests against the 'nix_agents' group. This group is
      # defined in inventory in BoltSpec::Conn.
      include_examples 'agentful tests', 'nix_agents'

      it 'runs successfully with a tty' do
        results = run_cli_json(%w[plan run basic::notify -t nix_agents --tty], project: project)

        results.each do |result|
          expect(result['status']).to eq('success')
        end
      end

      context 'in an apply block' do
        it 'gets resources' do
          results = run_cli_json(%w[plan run basic::resources -t nix_agents], project: project)

          results.each do |result|
            expect(result['status']).to eq('success')
            resources = result['value']['resources']
            expect(resources.map { |r| r['type'] }.uniq).to eq(%w[User File])
            expect(resources.select { |r| r['title'] == user && r['type'] == 'User' }.count).to eq(1)
            expect(resources.select { |r| r['title'] == '/tmp' && r['type'] == 'File' }.count).to eq(1)
          end
        end

        it 'errors when there are resource failures' do
          result = run_cli_json(%w[plan run basic::failure -t nix_agents], project: project, rescue_exec: true)
          expect(result).to include('kind' => 'bolt/apply-failure')
          error = result['details']['result_set'][0]['value']['_error']
          expect(error['kind']).to eq('bolt/resource-failure')
          expect(error['msg']).to match(/Resources failed to apply/)
        end

        it 'applies a notify and ignores local settings' do
          command = 'echo environment=doesnotexist > /etc/puppetlabs/puppet/puppet.conf'
          run_cli_json(%W[command run #{command} -t nix_agents], project: project)

          result = run_cli_json(%w[plan run basic::class -t nix_agents], project: project)
          expect(result).not_to include('kind')
          expect(result[0]).to include('status' => 'success')
          expect(result[0]['value']['_output']).to eq('changed: 1, failed: 0, unchanged: 0 skipped: 0, noop: 0')
          resources = result[0]['value']['report']['resource_statuses']
          expect(resources).to include('Notify[hello world]')
        end

        it 'respects _run_as on a plan invocation' do
          user = conn_info('ssh')[:user]
          logs = run_cli_json(%W[plan run basic::run_as_apply user=#{user} -t nix_agents], project: project)
          expect(logs.first['message']).to eq(conn_info('ssh')[:user])
        end

        it 'can reference project files with Puppet file syntax' do
          FileUtils.mkdir_p(project.path + 'files')
          FileUtils.touch(project.path + 'files' + 'testfile')

          result = run_cli_json(%W[plan run basic::project_files -t nix_agents project_name=#{project.name}],
                                project: project)

          expect(result.first).to include('status' => 'success')
        end

        context 'in a project with a name different than the directory' do
          let(:project_config) { base_config.merge('name' => 'example') }

          it 'can reference project files with Puppet file syntax' do
            FileUtils.mkdir_p(project.path + 'files')
            FileUtils.touch(project.path + 'files' + 'testfile')

            result = run_cli_json(%W[plan run basic::project_files -t nix_agents project_name=#{project.name}],
                                  project: project)

            expect(result.first).to include('status' => 'success')
          end
        end

        context 'with show_diff configured' do
          let(:apply_settings) { { 'show_diff' => true } }

          it 'respects show_diff configuration' do
            diff_string = <<~DIFF
              @@ -1 +1 @@
              -Silly string
              \\ No newline at end of file
              +Silly string (get it?)
              \\ No newline at end of file
            DIFF

            results = run_cli_json(%w[plan run settings::show_diff -t nix_agents], project: project)

            results.each do |result|
              expect(result['status']).to eq('success')
              expect(result['value']['report']['logs'][0]['message']).to include(diff_string)
            end
          end
        end

        context 'without trace configured' do
          it 'does not include backtrace in an error message' do
            results = run_cli_json(['apply', '-e', '1 < blue', '-t', 'nix_agents'], project: project)

            results.each do |result|
              expect(result['status']).to eq('failure')
              expect(result.dig('value', '_error', 'msg').lines.count).to eq(1)
            end
          end
        end

        context 'with trace configured' do
          let(:apply_settings) { { 'trace' => true } }

          it 'includes backtrace in an error message' do
            results = run_cli_json(['apply', '-e', '1 < blue', '-t', 'nix_agents'], project: project)

            results.each do |result|
              expect(result['status']).to eq('failure')
              expect(result.dig('value', '_error', 'msg').lines.count).to be > 1
              expect(result.dig('value', '_error', 'msg').lines).to include(/in `cmp_Numeric'/)
            end
          end
        end

        it 'with a target with no uri it uses the name as the certname' do
          results = run_cli_json(%w[plan run prep -t nix_agents], project: project)

          results.each do |result|
            expect(result['status']).to eq('success')
            report = result['value']['report']
            expect(report['resource_statuses']).to include(/Notify\[Hello puppet_[5-7]_node\]/)
          end
        end

        # Run on puppet_6_node and puppet_7_node only, as deferred requires >= 6.
        it 'applies the deferred type' do
          result = run_cli_json(%w[plan run basic::defer -t puppet_6_node,puppet_7_node], project: project)
          expect(result).not_to include('kind')
          expect(result[0]['status']).to eq('success')
          resources = result[0]['value']['report']['resource_statuses']

          local_pid = resources['Notify[local pid]']['events'][0]['desired_value'][/(\d+)/, 1]
          raise 'local pid was not found' if local_pid.nil?
          remote_pid = resources['Notify[remote pid]']['events'][0]['desired_value'][/(\d+)/, 1]
          raise 'remote pid was not found' if remote_pid.nil?
          expect(local_pid).not_to eq(remote_pid)
        end
      end

      context 'with the apply command' do
        it "applies a manifest" do
          manifest = project.path + 'manifest.pp'
          File.write(manifest, 'include basic')

          results = run_cli_json(%W[apply #{manifest} -t nix_agents], project: project)

          results.each do |result|
            result = result['value']
            expect(result).not_to include('kind')
            expect(result['report']).to include('status' => 'changed')
            expect(result['report']['resource_statuses']).to include('Notify[hello world]')
          end
        end

        it "applies with noop" do
          manifest = project.path + 'manifest.pp'
          File.write(manifest, 'include basic')

          results = run_cli_json(%W[apply #{manifest} --noop -t nix_agents], project: project)

          results.each do |result|
            result = result['value']
            expect(result).not_to include('kind')
            expect(result['report']).to include('status' => 'unchanged', 'noop' => true)
            expect(result['report']['resource_statuses']).to include('Notify[hello world]')
          end
        end

        it "applies a snippet of code" do
          code = 'include basic'
          results = run_cli_json(%W[apply -e #{code} -t nix_agents], project: project)

          results.each do |result|
            result = result['value']
            expect(result).not_to include('kind')
            expect(result['report']).to include('status' => 'changed')
            expect(result['report']['resource_statuses']).to include('Notify[hello world]')
          end
        end

        it "applies a node definition" do
          code = 'node default { notify { "hello world": } }'
          results = run_cli_json(%W[apply -e #{code} -t nix_agents], project: project)

          results.each do |result|
            result = result['value']
            expect(result).not_to include('kind')
            expect(result['report']).to include('status' => 'changed')
            expect(result['report']['resource_statuses']).to include('Notify[hello world]')
          end
        end

        it "fails if the manifest doesn't parse" do
          expect { run_cli_json(%w[apply -e include(basic -t nix_agents], project: project) }
            .to raise_error(/Syntax error/)
        end

        it "fails if the manifest doesn't compile" do
          code = 'include shmasic'
          results = run_cli_json(%W[apply -e #{code} -t nix_agents], project: project)

          results.each do |result|
            result = result['value']
            expect(result).to include('_error')
            expect(result['_error']['kind']).to eq('bolt/apply-error')
            expect(result['_error']['msg']).to match(/failed to compile/)
          end
        end
      end
    end

    # Run tests for installing the puppet-agent package using apply_prep.
    context 'installing puppet' do
      let(:config) do
        {
          'ssh' => {
            'host-key-check' => false,
            'run-as' => 'root',
            'password' => password
          }
        }
      end

      let(:inventory) do
        {
          'targets' => [{ 'uri' => uri }],
          'config' => config
        }
      end

      # Set up a project directory for the tests. Include an inventory file so Bolt
      # can actually connect to the target.
      around(:each) do |example|
        with_project(config: project_config, inventory: inventory) do |project|
          @project = project
          example.run
        end
      end

      # Ensure puppet is uninstalled after each test.
      after(:each) do
        uninstall(uri, inventory: inventory)
      end

      context 'with _run_as passed to apply_prep' do
        let(:config) do
          {
            'ssh' => {
              'host-key-check' => false,
              'password' => password
            }
          }
        end

        it 'installs puppet' do
          result = run_cli_json(%W[plan run prep::run_as -t #{uri}], project: project)

          expect(result).not_to include('kind')
          expect(result.count).to eq(1)
          expect(result[0]['status']).to eq('success')
          report = result[0]['value']['report']
          expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")
        end
      end

      it 'installs puppet' do
        result = run_cli_json(%W[plan run prep -t #{uri}], project: project)

        expect(result).not_to include('kind')
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        report = result[0]['value']['report']
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")
      end

      it 'succeeds when run twice' do
        result = run_cli_json(%W[plan run prep -t #{uri}], project: project)
        expect(result).not_to include('kind')
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        report = result[0]['value']['report']
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")

        # Includes agent facts from apply_prep
        agent_facts = report['resource_statuses']['Notify[agent facts]']['events'][0]['desired_value'].split("\n")
        expect(agent_facts[0]).to match(/^\w+/)
        expect(agent_facts[1]).to eq(agent_facts[0])
        expect(agent_facts[2]).to match(/^\d+\.\d+\.\d+$/)
        expect(agent_facts[3]).to eq(agent_facts[2])
        expect(agent_facts[4]).to eq('false')

        result = run_cli_json(%W[plan run prep -t #{uri}], project: project)
        expect(result.count).to eq(1)
        expect(result[0]['status']).to eq('success')
        report = result[0]['value']['report']
        expect(report['resource_statuses']).to include("Notify[Hello #{conn_uri('ssh')}]")
      end

      it 'returns both failing and successful results' do
        result = run_cli_json(%W[apply -e notice('hello') -t #{uri},foobar], project: project)

        expect(result.size).to eq(2)
        expect(result[0]).to include(
          'target' => 'foobar',
          'status' => 'failure'
        )
        expect(result[1]).to include(
          'target' => uri,
          'status' => 'success'
        )
      end

      context 'with plugin configured' do
        let(:inventory) do
          {
            'targets' => [
              {
                'uri' => uri,
                'plugin_hooks' => {
                  'puppet_library' => {
                    'plugin' => 'puppet_agent'
                  }
                }
              }
            ],
            'config' => config
          }
        end

        it 'installs puppet' do
          result = run_cli_json(%W[plan run prep -t #{uri}], project: project)

          expect(result).not_to include('kind')
          expect(result.count).to eq(1)
          expect(result[0]['status']).to eq('success')
          report = result[0]['value']['report']
          expect(report['resource_statuses']).to include("Notify[Hello #{uri}]")
        end
      end

      context 'with task plugin configured' do
        let(:inventory) do
          {
            'targets' => [
              {
                'uri' => uri,
                'plugin_hooks' => {
                  'puppet_library' => {
                    'plugin' => 'task',
                    'task' => 'puppet_agent::install',
                    'parameters' => {
                      'version' => '7.0.0'
                    }
                  }
                }
              }
            ],
            'config' => config
          }
        end

        it 'installs puppet' do
          result = run_cli_json(%W[plan run prep -t #{uri}], project: project)

          expect(result).not_to include('kind')
          expect(result.count).to eq(1)
          expect(result[0]['status']).to eq('success')
          report = result[0]['value']['report']
          expect(report['resource_statuses']).to include("Notify[Hello #{uri}]")

          results = run_cli_json(%W[task run puppet_agent::version -t #{uri}], project: project)

          result = results['items']
          expect(result.count).to eq(1)
          expect(result[0]).to include('status' => 'success')
          expect(result[0]['value']['version']).to match(/^7\.0/)
        end
      end

      context 'with bad plugin configuration' do
        let(:inventory) do
          {
            'targets' => [
              {
                'uri' => uri,
                'name' => 'error',
                'plugin_hooks' => {
                  'puppet_library' => {
                    'plugin' => 'task',
                    'task' => 'prep::error'
                  }
                }
              },
              {
                'uri' => uri,
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
              },
              {
                'uri' => uri,
                'name' => 'badplugin',
                'plugin_hooks' => {
                  'puppet_library' => {
                    'plugin' => 'what plugin?'
                  }
                }
              }
            ],
            'config' => config
          }
        end

        it 'errors appropriately for each target' do
          result = run_cli_json(%w[plan run prep -t all], project: project)

          expect(result['kind']).to eq('bolt/run-failure')
          expect(result['msg']).to eq("apply_prep failed on 3 targets")

          result_set = result['details']['result_set']
          task_error = result_set.select { |h| h['target'] == 'error' }[0]['value']['_error']
          expect(task_error['kind']).to eq('puppetlabs.tasks/task-error')
          expect(task_error['msg']).to include("The task failed with exit code 1")

          param_error = result_set.select { |h| h['target'] == 'badparams' }[0]['value']['_error']
          expect(param_error['kind']).to eq('bolt/plugin-error')
          expect(param_error['msg']).to match(
            /Task puppet_agent::install.*parameter 'collection' expects an undef value/m
          )

          plugin_error = result_set.select { |h| h['target'] == 'badplugin' }[0]['value']['_error']
          expect(plugin_error['kind']).to eq('bolt/unknown-plugin')
          expect(plugin_error['msg']).to include("Unknown plugin: 'what plugin?'")
        end
      end
    end
  end

  describe 'over winrm on Windows with Puppet Agents', winrm: true do
    around(:each) do |example|
      with_project(config: project_config, inventory: conn_inventory) do |project|
        @project = project
        example.run
      end
    end

    TEST_VERSIONS.each do |version, collection|
      context "with puppet#{version} installed" do
        before(:all) do
          install('winrm', collection: collection, inventory: conn_inventory)
        end

        after(:all) do
          uninstall('winrm', inventory: conn_inventory)
        end

        include_examples 'agentful tests', 'winrm'
      end
    end
  end
end
