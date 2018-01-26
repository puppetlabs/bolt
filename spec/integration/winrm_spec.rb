require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when runnning over the winrm transport", winrm: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:whoami) { "echo $env:UserName" }
  let(:stdin_task) { "sample::winstdin" }
  let(:uri) { conn_uri('winrm') }
  let(:password) { conn_info('winrm')[:password] }
  let(:user) { conn_info('winrm')[:user] }

  context 'when using CLI options' do
    let(:config_flags) { %W[--nodes #{uri} --no-ssl --format json --modulepath #{modulepath} --password #{password}] }

    it 'runs a command' do
      result = run_one_node(%W[command run #{whoami}] + config_flags)
      expect(result['stdout'].strip).to eq(user)
    end

    it 'reports errors when command fails' do
      result = run_failed_node(%w[command run boop] + config_flags)
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/command-error')
      expect(result['_error']['msg']).to eq('The command failed with exit code 1')
    end

    it 'runs a task', reset_puppet_settings: true do
      result = run_one_node(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(result['_output'].strip).to match(/STDIN: {"messa/)
    end

    it 'reports errors when task fails', reset_puppet_settings: true do
      result = run_failed_node(%w[task run results::win] + config_flags)
      expect(result['_error']['kind']).to eq('puppetlabs.tasks/task-error')
      expect(result['_error']['msg']).to eq("The task failed with exit code 1:\n")
    end

    it 'passes noop to a task that supports noop', reset_puppet_settings: true do
      result = run_one_node(%w[task run sample::ps_noop message=somemessage --noop] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop true")
    end

    it 'does not pass noop to a task by default', reset_puppet_settings: true do
      result = run_one_node(%w[task run sample::ps_noop message=somemessage] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop")
    end
  end

  context 'when using a configfile' do
    let(:config) { { 'format' => 'json', 'modulepath' => modulepath, 'winrm' => { 'ssl' => false } } }
    let(:config_flags) { %W[--nodes #{uri} --password #{password}] }

    it 'runs a command' do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[command run #{whoami} --configfile #{conf.path}] + config_flags)
        expect(result['stdout'].strip).to eq(user)
      end
    end

    it 'runs a task', reset_puppet_settings: true do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[task run #{stdin_task} message=somemessage --configfile #{conf.path}] + config_flags)
        expect(result['_output'].strip).to match(/STDIN: {"messa/)
      end
    end
  end
end
