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
          transports: {
            conn[:protocol] => {
              user: conn[:user],
              port: conn[:port]
            }
          }
        } }
    ],
      config: {
        transports: {
          ssh: { host_key_check: false },
          winrm: { ssl: false }
        }
      } }
  end

  let(:modulepath) { fixture_path('modules') }
  let(:config_flags) {
    ['--format', 'json',
     '--inventoryfile', @inventoryfile,
     '--configfile', fixture_path('configs', 'empty.yml'),
     '--modulepath', modulepath,
     '--password', conn[:password]]
  }

  let(:run_command) { ['command', 'run', whoami, '--nodes', conn[:host]] + config_flags }

  let(:run_plan) { ['plan', 'run', 'inventory', "command=#{whoami}", "host=#{conn[:host]}"] + config_flags }

  around(:each) do |example|
    with_tempfile_containing('inventory', inventory.to_json, '.yml') do |f|
      @inventoryfile = f.path
      example.run
    end
  end

  context 'when running over ssh', ssh: true do
    let(:whoami) { "whoami" }

    it 'connects to run a command' do
      result = run_one_node(run_command)
      expect(result).to be
    end

    it 'connects to run a plan' do
      # result = run_cli(run_plan)
      expect(run_cli_json(run_plan)[0]['status']).to eq('success')
    end
  end

  context 'when running over winrm', winrm: true do
    let(:conn) { conn_info('winrm') }
    let(:whoami) { "echo $env:UserName" }

    it 'connects to run a command' do
      expect(run_one_node(run_command)).to be
    end

    it 'connects to run a plan' do
      expect(run_cli_json(run_plan)[0]['status']).to eq('success')
    end
  end
end
