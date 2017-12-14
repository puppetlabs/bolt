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
    let(:config_flags) { %W[--nodes #{uri} --insecure --format json --modulepath #{modulepath} --password #{password}] }

    it 'runs a command' do
      result = run_one_node(%W[command run #{whoami}] + config_flags)
      expect(result['stdout'].strip).to eq(user)
    end

    it 'runs a task', reset_puppet_settings: true do
      result = run_one_node(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(result['_output'].strip).to match(/STDIN: {"messa/)
    end
  end

  context 'when using a configfile' do
    let(:config) { { 'format' => 'json', 'modulepath' => modulepath, 'winrm' => { 'insecure' => true } } }
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
