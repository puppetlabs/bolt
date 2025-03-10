# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "when runnning over the jail transport", jail: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:whoami) { "whoami" }
  let(:modulepath) { fixtures_path('modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:uri) { conn_uri('jail') }
  let(:user) { conn_info('jail')[:user] }
  let(:password) { conn_info('jail')[:password] }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  context 'when using CLI options' do
    let(:config_flags) {
      %W[--targets #{uri} --no-host-key-check --format json --modulepath #{modulepath} --password #{password}]
    }

    it 'runs a command' do
      result = run_one_node(%W[command run #{whoami}] + config_flags)
      expect(result['stdout'].strip).to eq('root')
    end

    it 'reports errors when command fails' do
      result = run_failed_node(%w[command run boop] + config_flags)
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/command-error')
      expect(result['_error']['msg']).to eq('The command failed with exit code 1')
    end

    it 'runs a task', :reset_puppet_settings do
      result = run_one_node(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(result['message'].strip).to eq("somemessage")
    end

    it 'reports errors when task fails', :reset_puppet_settings do
      result = run_failed_node(%w[task run results fail=true] + config_flags)
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/task-error')
      expect(result['_error']['msg']).to eq("The task failed with exit code 1 and no output")
    end

    it 'passes noop to a task that supports noop', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::noop message=somemessage --noop] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop true")
    end

    it 'passes noop to a plan that runs a task with noop', :reset_puppet_settings do
      result = run_cli_json(%w[plan run sample::noop] + config_flags)[0]['value']
      expect(result['_output'].strip).to eq("This works with noop true")
    end

    it 'does not pass noop to a task by default', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::noop message=somemessage] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop")
    end

    it 'escalates privileges when passed --run-as' do
      result = run_one_node(%W[command run #{whoami} --run-as root --sudo-password #{password}] + config_flags)
      expect(result['stdout'].strip).to eq("root")
      result = run_one_node(%W[command run #{whoami} --run-as #{user} --sudo-password #{password}] + config_flags)
      expect(result['stdout'].strip).to eq(user)
    end
  end

  context 'when using a project', :reset_puppet_settings do
    let(:config) do
      {
        'format'     => 'json',
        'future'     => future_config,
        'modulepath' => modulepath
      }
    end

    let(:future_config) { {} }

    let(:default_inv) do
      {
        'config' => {
          'jail' => {}
        }
      }
    end

    let(:inv)                { default_inv }
    let(:uri)                { (1..2).map { |i| "#{conn_uri('jail')}?id=#{i}" }.join(',') }
    let(:project)            { @project }
    let(:config_flags)       { %W[--targets #{uri} --project #{project.path}] }
    let(:single_target_conf) { %W[--targets #{conn_uri('jail')} --project #{project.path}] }
    let(:interpreter_task)   { 'sample::interpreter' }
    let(:interpreter_script) { 'sample/scripts/script.py' }

    let(:run_as_conf) do
      {
        'config' => {
          'jail' => {}
        }
      }
    end

    let(:interpreter_ext) do
      {
        'config' => {
          'jail' => {
            'interpreters' => {
              '.py' => '/usr/local/bin/python3.9'
            }
          }
        }
      }
    end

    let(:interpreter_no_ext) do
      {
        'config' => {
          'jail' => {
            'interpreters' => {
              'py' => '/usr/local/bin/python3.9'
            }
          }
        }
      }
    end

    let(:interpreter_array) do
      {
        'config' => {
          'jail' => {
            'interpreters' => {
              'py' => ['/usr/local/bin/python3.9', '-d']
            }
          }
        }
      }
    end

    around :each do |example|
      with_project(config: config, inventory: inv) do |project|
        @project = project
        example.run
      end
    end

    shared_examples 'script interpreter' do
      it 'does not run script with specified interpreter' do
        result = run_cli_json(%W[script run #{interpreter_script}] + config_flags)['items'][0]
        expect(result['status']).to eq('failure')
        expect(result['value']['exit_code']).to eq(2)
        expect(result['value']['stderr']).to match(/word unexpected/)
      end

      context 'with future.script_interpreter configured' do
        let(:future_config) do
          {
            'script_interpreter' => true
          }
        end

        it 'runs script with specified interpreter' do
          result = run_cli_json(%W[script run #{interpreter_script}] + config_flags)['items'][0]
          expect(result['status']).to eq('success')
          expect(result['value']['exit_code']).to eq(0)
          expect(result['value']['stdout']).to match(/Hello, world!/)
        end
      end
    end

    it 'runs multiple commands' do
      result = run_nodes(%W[command run #{whoami}] + config_flags)
      expect(result.map { |r| r['stdout'].strip }).to eq([user, user])
    end

    it 'runs multiple tasks' do
      result = run_nodes(%W[task run #{stdin_task} message=short] + config_flags)
      expect(result.map { |r| r['message'].strip }).to eq(%w[short short])
    end

    context 'with run-as configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, run_as_conf) }

      it 'runs multiple tasks as a specified user' do
        result = run_nodes(%W[command run #{whoami} --sudo-password #{password}] + config_flags)
        expect(result.map { |r| r['stdout'].strip }).to eq([user, user])
      end
    end

    context 'with interpreters without dots configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_no_ext) }

      include_examples 'script interpreter'

      it 'runs task with specified interpreter key py' do
        result = run_nodes(%W[task run #{interpreter_task} message=short] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end

      it 'runs task with specified interpreter that with run-as set' do
        result = run_nodes(%W[task run #{interpreter_task} message=short
                              --run-as root --sudo-password #{password}] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    context 'with interpreters with dots configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_ext) }

      include_examples 'script interpreter'

      it 'runs task with interpreter key .py' do
        result = run_nodes(%W[task run #{interpreter_task} message=short] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    context 'with interpreters as an array' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_array) }

      include_examples 'script interpreter'

      it 'runs task with interpreter value as array' do
        result = run_nodes(%W[task run #{interpreter_task} message=short] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    it 'task fails when bad shebang is not overriden' do
      result = run_failed_node(%W[task run #{interpreter_task} message=short] + single_target_conf)
      expect(result['_error']['msg']).to match(/interpreter.py: not found/)
    end
  end
end
