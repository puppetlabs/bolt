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
    { nodes: [
      { name: conn[:host],
        config: {
          transport: conn[:protocol],
          conn[:protocol] => {
            user: conn[:user],
            port: conn[:port]
          }
        } }
    ],
      config: {
        ssh: { 'host-key-check' => false },
        winrm: { ssl: false }
      },
      vars: {
        daffy: "duck"
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

  context 'when running over ssh', ssh: true do
    let(:shell_cmd) { "whoami" }

    it 'connects to run a command' do
      result = run_one_node(run_command)
      expect(result).to be
    end

    it 'connects to run a plan' do
      expect(run_cli_json(run_plan)[0]['status']).to eq('success')
    end

    context 'with a group' do
      let(:target) { 'all' }

      it 'runs a command' do
        expect(run_one_node(run_command)).to be
      end

      it 'runs a plan using a group' do
        expect(run_cli_json(run_plan)[0]['status']).to eq('success')
      end
    end

    context 'with variables set' do
      let(:var_plan) { ['plan', 'run', 'vars', "host=#{target}"] + config_flags }
      let(:output) { "Vars for localhost: {daffy => duck, bugs => bunny}\n" }
      it 'sets a variable on the target' do
        expect(run_cli_json(var_plan)[0]['result']['stdout']).to eq(output)
      end

      it 'preserves variables between runs', :reset_puppet_settings do
        run_cli_json(run_command)
        expect(run_cli_json(var_plan)[0]['result']['stdout']).to eq(output)
      end
    end
  end

  context 'when running over winrm', winrm: true do
    let(:conn) { conn_info('winrm') }
    let(:shell_cmd) { "echo $env:UserName" }

    it 'connects to run a command' do
      expect(run_one_node(run_command)).to be
    end

    it 'connects to run a plan' do
      expect(run_cli_json(run_plan)[0]['status']).to eq('success')
    end

    context 'with a group' do
      let(:target) { 'all' }

      it 'connects to run a command' do
        expect(run_one_node(run_command)).to be
      end

      it 'connects to run a plan' do
        expect(run_cli_json(run_plan)[0]['status']).to eq('success')
      end
    end
  end

  context 'when running over local', bash: true do
    let(:shell_cmd) { "whoami" }

    let(:inventory) do
      {}
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
        let(:inventory) { { nodes: ['localhost'] } }

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
            nodes: ['localhost'],
            config: {
              transport: 'local',
              local: { tmpdir: tmpdir }
            }
          }
        end

        before(:each) { `mkdir #{tmpdir}` }
        after(:each) { `rm -rf #{tmpdir}` }

        it 'uses tmpdir' do
          expect(run_one_node(run_command)['stdout'].strip).to match(/#{Regexp.escape(tmpdir)}/)
        end
      end

      context 'with localhost specifying tmpdir via node' do
        let(:tmpdir) { '/tmp/foo' }
        let(:shell_cmd) { 'pwd' }
        let(:inventory) do
          {
            nodes: [{
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
          expect(run_one_node(run_command)['stdout'].strip).to match(/#{Regexp.escape(tmpdir)}/)
        end
      end
    end
  end
end
