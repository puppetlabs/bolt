# frozen_string_literal: true

require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "when runnning over the winrm transport", winrm: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:modulepath) { fixtures_path('modules') }
  let(:whoami) { "echo $env:UserName" }
  let(:uri) { conn_uri('winrm') }
  let(:password) { conn_info('winrm')[:password] }
  let(:user) { conn_info('winrm')[:user] }

  context 'when using CLI options' do
    let(:config_flags) {
      %W[--targets #{uri} --no-ssl --no-ssl-verify --format json --modulepath #{modulepath}
         --password #{password}]
    }

    it 'runs a command' do
      result = run_one_node(%W[command run #{whoami}] + config_flags)
      expect(result['stdout'].strip).to eq(user)
    end

    it 'reports errors when command fails' do
      result = run_failed_node(%w[command run boop] + config_flags)
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/command-error')
      expect(result['_error']['msg']).to eq('The command failed with exit code 1')
    end

    it 'runs a task reading from stdin', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::winstdin message=µsomemessage] + config_flags)
      output = result['_output'].strip
      expect(output).to match(/STDIN: {"message":"µsomemessage"/)
    end

    it 'runs a task reading from $input', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::wininput message=µsomemessage] + config_flags)
      output = result['_output'].strip
      expect(output).to match(/INPUT: {"message":"µsomemessage"/)
    end

    it 'runs a task with parameters', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::winparams message=µsomemessage] + config_flags)
      output = result['_output'].strip
      expect(output).to match(/Message: µsomemessage/)
    end

    it 'runs a task reading from environment variables', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::winenv message=somemessage] + config_flags)
      output = result['_output'].strip
      expect(output).to match(/ENV: somemessage/)
    end

    it 'runs a task with complex parameters', :reset_puppet_settings do
      complex_input_file = fixtures_path('complex_params', 'input.json')
      expected = File.open(fixtures_path('complex_params', 'output'), 'rb', &:read)

      result = run_one_node(%W[task run sample::complex_params --params @#{complex_input_file}] + config_flags)
      expect(result['_output']).to eq(expected)
    end

    it 'reports errors when task fails', :reset_puppet_settings do
      result = run_failed_node(%w[task run results::win] + config_flags)
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/task-error')
      expect(result['_error']['msg']).to eq("The task failed with exit code 1 and no output")
    end

    it 'passes noop to a task that supports noop', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::ps_noop message=somemessage --noop] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop True")
    end

    it 'does not pass noop to a task by default', :reset_puppet_settings do
      result = run_one_node(%w[task run sample::ps_noop message=somemessage] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop")
    end

    it 'handles disconnects gracefully', :reset_puppet_settings do
      result = run_cli_json(%w[plan run error::winrm_disconnect] + config_flags)
      expect(result.first['status']).to eq("success")
    end
  end

  context 'when using an inventoryfile', :reset_puppet_settings do
    let(:config) do
      {
        'future' => future_config
      }
    end

    let(:future_config) { {} }

    let(:default_inv) do
      {
        'config' => {
          'winrm' => {
            'user' => user,
            'password' => password,
            'ssl' => false,
            'ssl-verify' => false
          }
        }
      }
    end

    let(:inv)                { default_inv }
    let(:uri)                { (1..2).map { |i| "#{conn_uri('winrm')}?id=#{i}" }.join(',') }
    let(:project)            { @project }
    let(:common_flags)       { %W[--format json --modulepath #{modulepath} --project #{project.path}] }
    let(:config_flags)       { %W[--targets #{uri}] + common_flags }
    let(:single_target)      { %W[--targets #{conn_uri('winrm')}] + common_flags }
    let(:interpreter_task)   { 'sample::bolt_ruby' }
    let(:interpreter_script) { 'sample/scripts/script.rb' }

    let(:interpreter_ext) do
      {
        'config' => {
          'winrm' => {
            'interpreters' => {
              '.rb' => RbConfig.ruby
            }
          }
        }
      }
    end

    let(:interpreter_no_ext) do
      {
        'config' => {
          'winrm' => {
            'interpreters' => {
              'rb' => RbConfig.ruby
            }
          }
        }
      }
    end

    let(:bad_interpreter) do
      {
        'config' => {
          'winrm' => {
            'interpreters' => {
              'rb' => 'C:\dev\null'
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

    it 'runs multiple commands' do
      result = run_nodes(%W[command run #{whoami}] + config_flags)
      expect(result.map { |r| r['stdout'].strip }).to eq([user, user])
    end

    it 'runs multiple tasks' do
      results = run_nodes(%w[task run sample::winstdin message=short] + config_flags)
      results.each do |result|
        expect(result['_output'].strip).to match(/STDIN: {"messa/)
      end
    end

    context 'with interpreters without dots configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_no_ext) }

      it 'runs task with specified interpreter key rb', windows: true do
        result = run_nodes(%W[task run #{interpreter_task} message=short] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    context 'with interpreters with dots configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_ext) }

      it 'runs task with interpreter key .rb', windows: true do
        result = run_nodes(%W[task run #{interpreter_task} message=short] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    context 'with a bad interpreter' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, bad_interpreter) }

      it 'task fails with bad interpreter', windows: true do
        result = run_failed_node(%W[task run #{interpreter_task} message=short] + single_target)
        expect(result['_error']['msg']).to match(/'C:\\dev\\null' is not recognized/)
      end
    end

    context 'script interpreter' do
      # Windows automatically searches for an interpreter if one is not
      # specified. We use a bad interpreter here to check that the interpreter
      # is being set correctly, otherwise Windows would just find the Ruby
      # interpreter on its own.
      let(:inv) { Bolt::Util.deep_merge(default_inv, bad_interpreter) }

      context 'without future.script_interpreter configured' do
        it 'does not run script with specified interpreter' do
          result = run_cli_json(%W[script run #{interpreter_script}] + config_flags)['items'][0]
          expect(result['status']).to eq('success')
          expect(result['value']['stdout']).to match(/Hello, world!/)
        end
      end

      context 'with future.script_interpreter configured' do
        let(:future_config) do
          {
            'script_interpreter' => true
          }
        end

        it 'runs script with specified interpreter' do
          result = run_cli_json(%W[script run #{interpreter_script}] + config_flags)['items'][0]
          expect(result['status']).to eq('failure')
          expect(result['value']['stdout']).not_to match(/Hello, world!/)
        end
      end
    end
  end
end
