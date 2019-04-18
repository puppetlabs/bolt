# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'running with an inventory file', reset_puppet_settings: true do
  include BoltSpec::Config
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:conn) { conn_info('ssh') }
  let(:inventory) do
    { version: 2,
      targets: [
        { uri: conn[:host],
          config: {
            transport: conn[:protocol],
            conn[:protocol] => {
              user: conn[:user],
              port: conn[:port]
            }
          } },
        { name: 'uriless',
          config: {
            transport: conn[:protocol],
            conn[:protocol] => {
              host: conn[:host],
              user: conn[:user],
              port: conn[:port]
            }
          } },
        { name: 'hostless',
          config: {
            transport: conn[:protocol]
          } }
      ],
      groups: [{
        name: "group1",
        targets: [
          conn[:host]
        ]
      }],
      config: {
        ssh: { 'host-key-check' => false },
        winrm: { ssl: false, 'ssl-verify' => false }
      },
      vars: {
        daffy: "duck"
      },
      facts: {
        scooby: 'doo',
        cloud: {
          provider: 'Azure',
          foo: 'bar'
        }
      } }
  end
  let(:target) { conn[:host] }

  let(:modulepath) { fixture_path('modules') }
  let(:config_flags) {
    ['--format', 'json',
     '--inventoryfile', @inventoryfile,
     '--configfile', fixture_path('configs', 'empty.yml'),
     '--modulepath', modulepath,
     '--password', conn[:password]]
  }

  let(:run_command) { ['command', 'run', shell_cmd, '--nodes', target] + config_flags }

  let(:run_plan) { ['plan', 'run', 'inventory', "command=#{shell_cmd}", "host=#{target}"] + config_flags }

  around(:each) do |example|
    with_tempfile_containing('inventory', inventory.to_json, '.yml') do |f|
      @inventoryfile = f.path
      example.run
    end
  end

  shared_examples 'basic inventory' do
    it 'connects to run a command' do
      result = run_one_node(run_command)
      expect(result).to be
    end

    context 'with a uriless target' do
      let(:target) { 'uriless' }
      it 'connects to run a command' do
        result = run_one_node(run_command)
        expect(result).to be
      end
    end

    it 'connects to run a plan' do
      expect(run_cli_json(run_plan)[0]).to include('status' => 'success')
    end

    context 'with a group' do
      let(:target) { 'group1' }

      it 'runs a command' do
        expect(run_one_node(run_command)).to be
      end

      it 'runs a plan using a group' do
        expect(run_cli_json(run_plan)[0]['status']).to eq('success')
      end
    end
  end

  context 'when running a plan' do
    let(:run_plan) { ['plan', 'run', 'inventory::get_host'] + config_flags }
    it 'can access the host' do
      r = run_cli_json(run_plan + ['--nodes', 'hostless'])
      expect(r).to eq('result' => nil)
    end
  end

  context 'when running over ssh', ssh: true do
    let(:shell_cmd) { "whoami" }

    include_examples 'basic inventory'

    context 'with variables set' do
      let(:output) { "Vars for localhost: {daffy => duck, bugs => bunny}" }

      def var_plan(name = 'vars')
        ['plan', 'run', name, "host=#{target}"] + config_flags
      end

      it 'sets a variable on the target' do
        expect(run_cli_json(var_plan)).to eq(output)
      end

      it 'preserves variables between runs', :reset_puppet_settings do
        run_cli_json(run_command)
        expect(run_cli_json(var_plan)).to eq(output)
      end

      context 'with target not in inventory' do
        let(:inventory) { { version: 2 } }

        it 'does not error when facts are retrieved' do
          expect(run_cli_json(var_plan('vars::emit'))).to eq("Vars for localhost: {}")
        end

        it 'does not error when facts are added' do
          expect(run_cli_json(var_plan)).to eq("Vars for localhost: {bugs => bunny}")
        end
      end
    end

    context 'with facts set' do
      # This also asserts the deep_merge works
      let(:output) {
        "Facts for localhost: {scooby => doo, cloud => {provider => AWS, " \
        "foo => bar}, kernel => Linux}"
      }

      def fact_plan(name = 'facts_test')
        ['plan', 'run', name, "host=#{target}"] + config_flags
      end

      it 'sets a facts hash on the target' do
        expect(run_cli_json(fact_plan)).to eq(output)
      end

      it 'preserves facts between runs', :reset_puppet_settings do
        run_cli_json(run_command)
        expect(run_cli_json(fact_plan)).to eq(output)
      end

      context 'with target not in inventory' do
        let(:inventory) { { version: 2 } }

        it 'does not error when facts are retrieved' do
          expect(run_cli_json(fact_plan('facts_test::emit'))).to eq("Facts for localhost: {}")
        end

        it 'does not error when facts are added' do
          expect(run_cli_json(fact_plan)).to eq("Facts for localhost: {kernel => Linux, cloud => {provider => AWS}}")
        end
      end
    end
  end

  context 'when adding targets to a group in a plan', ssh: true do
    let(:conn) { conn_info('ssh') }
    let(:inventory) do
      {
        version: 2,
        groups: [
          {
            name: 'foo',
            targets: [
              {
                name: 'foo_1'
              }
            ],
            config: {
              transport: 'local'
            },
            facts: {
              parent: 'keep',
              preserve_hierarchy: 'keep',
              override_parent: 'discard'
            },
            vars: {
              parent: 'keep',
              preserve_hierarchy: 'keep',
              override_parent: 'discard'
            },
            groups: [
              {
                name: 'add_me',
                targets: [
                  {
                    uri: conn[:host]
                  }
                ],
                config: {
                  transport: conn[:protocol],
                  conn[:protocol] => {
                    user: conn[:user],
                    port: conn[:port]
                  }
                },
                facts: {
                  added_group: 'keep'
                },
                vars: {
                  added_group: 'keep'
                }
              }
            ]
          },
          {
            name: 'bar',
            targets: [
              {
                uri: 'bar_1',
                vars: { bar_1_var: 'dont_overwrite' }
              }
            ],
            config: {
              transport: 'local'
            },
            facts: {
              exclude: 'dont_inherit'
            },
            vars: {
              exclude: 'dont_inherit'
            }
          }
        ],
        facts: {
          top_level: 'keep',
          preserve_hierarchy: 'discard'
        },
        vars: {
          top_level: 'keep',
          preserve_hierarchy: 'discard'
        }
      }
    end

    it 'computes facts and vars based on group hierarchy' do
      plan = ['plan', 'run', 'add_group', '--nodes', 'add_me'] + config_flags
      expected_hash_pre = { 'top_level' => 'keep',
                            'preserve_hierarchy' => 'keep',
                            'parent' => 'keep',
                            'override_parent' => 'discard',
                            'added_group' => 'keep' }
      expected_hash_post = expected_hash_pre.merge('override_parent' => 'keep', 'plan_context' => 'keep')
      result = run_cli_json(plan)
      expect(result)
        .to include(
          'addme_group' =>
            ["Target('#{conn[:host]}', {\"user\"=>\"#{conn[:user]}\", \"port\"=>#{conn[:port]}})",
             "Target('0.0.0.0:20024', {\"user\"=>\"bolt\", \"port\"=>20022})"]
        )
      expect(result['existing_facts']).to eq(expected_hash_pre)
      expect(result['existing_vars']).to eq(expected_hash_pre)
      expect(result['added_facts']).to eq(expected_hash_post)
      expect(result['added_vars']).to eq(expected_hash_post)
      expect(result['target_not_overwritten']).to eq("dont_overwrite")
      expect(result['target_not_duplicated']).to eq(["Target('bar_1', {})"])
      expect(result['target_to_all_group']).to include("Target('add_to_all', {})")
    end

    it 'errors when trying to add to non-existent group' do
      plan = ['plan', 'run', 'add_group::x_fail_non_existent_group', '--nodes', 'add_me'] + config_flags
      result = run_cli_json(plan)
      expect(result['kind']).to eq('bolt.inventory/validation-error')
      expect(result['msg']).to match(/Group does_not_exist does not exist in inventory/)
    end

    it 'errors when trying to add new target with name that conflicts with group name' do
      plan = ['plan', 'run', 'add_group::x_fail_group_name_exists', '--nodes', 'add_me'] + config_flags
      result = run_cli_json(plan)
      expect(result['kind']).to eq('bolt.inventory/validation-error')
      expect(result['msg']).to match(/Group foo conflicts with target of the same name for group/)
      expect(result['details']).to eq("path" => ["foo"])
    end
  end

  context 'when running over winrm', winrm: true do
    let(:conn) { conn_info('winrm') }
    let(:shell_cmd) { "echo $env:UserName" }

    include_examples 'basic inventory'
  end

  context 'when running over docker', docker: true do
    let(:conn) { conn_info('docker') }
    let(:shell_cmd) { "whoami" }

    include_examples 'basic inventory'
  end

  context 'when running over remote', bash: true do
    let(:inventory) do
      { version: 2,
        targets: [
          { name: 'remote_target',
            config: {
              transport: 'remote',
              remote: {
                host: 'not.the.name'
              }
            } }
        ] }
    end

    it 'passes the correct host to the task' do
      task = ['task', 'run', 'remote', '--nodes', 'remote_target'] + config_flags
      result = run_one_node(task)
      expect(result['_target']).to include('host' => 'not.the.name')
    end
  end

  context 'when running over local', bash: true do
    let(:shell_cmd) { "whoami" }

    let(:inventory) do
      { version: 2 }
    end

    let(:config_flags) {
      ['--format', 'json',
       '--inventoryfile', @inventoryfile,
       '--configfile', fixture_path('configs', 'empty.yml'),
       '--modulepath', modulepath]
    }

    context 'with local://' do
      let(:target) { 'local://host' }

      it 'connects to run a command' do
        expect(run_one_node(run_command)).to be
      end

      it 'connects to run a plan' do
        expect(run_cli_json(run_plan)[0]['status']).to eq('success')
      end
    end

    context 'with localhost' do
      let(:target) { 'localhost' }

      it 'connects to run a command' do
        expect(run_one_node(run_command)).to be
      end

      it 'connects to run a plan' do
        expect(run_cli_json(run_plan)[0]['status']).to eq('success')
      end

      context 'with localhost in inventory' do
        let(:inventory) do
          # Ensure that we try to connect to a *closed* port, to avoid spurious "success"
          port = TCPServer.open(0) { |socket| socket.addr[1] }
          config = { transport: 'ssh', ssh: { port: port } }
          { version: 2,
            targets: ['localhost'], config: config }
        end

        it 'fails to connect' do
          result = run_failed_node(run_command)
          expect(result['_error']['kind']).to eq('puppetlabs.tasks/connect-error')
        end
      end

      context 'with localhost specifying tmpdir via group' do
        let(:tmpdir) { '/tmp/foo' }
        let(:shell_cmd) { 'pwd' }
        let(:inventory) do
          {
            version: 2,
            targets: ['localhost'],
            config: {
              transport: 'local',
              local: { tmpdir: tmpdir }
            }
          }
        end

        before(:each) { `mkdir #{tmpdir}` }
        after(:each) { `rm -rf #{tmpdir}` }

        it 'uses tmpdir' do
          with_tempfile_containing('script', 'echo "`dirname $0`"', '.sh') do |f|
            run_script = ['script', 'run', f.path, '--nodes', target] + config_flags
            expect(run_one_node(run_script)['stdout'].strip).to match(/#{Regexp.escape(tmpdir)}/)
          end
        end
      end

      context 'with localhost specifying tmpdir via target' do
        let(:tmpdir) { '/tmp/foo' }
        let(:shell_cmd) { 'pwd' }
        let(:inventory) do
          {
            version: 2,
            targets: [{
              name: 'localhost',
              config: {
                transport: 'local',
                local: { tmpdir: tmpdir }
              }
            }]
          }
        end

        before(:each) { `mkdir #{tmpdir}` }
        after(:each) { `rm -rf #{tmpdir}` }

        it 'uses tmpdir' do
          with_tempfile_containing('script', 'echo "`dirname $0`"', '.sh') do |f|
            run_script = ['script', 'run', f.path, '--nodes', target] + config_flags
            expect(run_one_node(run_script)['stdout'].strip).to match(/#{Regexp.escape(tmpdir)}/)
          end
        end
      end
    end
  end
end
