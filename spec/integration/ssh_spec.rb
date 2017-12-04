require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when runnning over the ssh transport", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:uri) { conn_uri('ssh') }
  let(:password) { conn_info('ssh')[:password] }

  context 'when using CLI options' do
    let(:config_flags) { %W[--nodes #{uri} --insecure --format json --modulepath #{modulepath} --password #{password}] }

    it 'runs a command' do
      result = run_one_node(%W[command run #{whoami}] + config_flags)
      expect(result['stdout'].strip).to eq(
        conn_info('ssh')[:user]
      )
    end

    it 'runs a task' do
      result = run_one_node(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(result['message'].strip).to eq("somemessage")
    end
  end

  context 'when using a configfile' do
    let(:config) do
      { 'format' => 'json',
        'modulepath' => modulepath,
        'ssh' => {
          'insecure' => true
        } }
    end

    let(:config_flags) { %W[--nodes #{uri} --password #{password}] }

    it 'runs a command' do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[command run #{whoami} --configfile #{conf.path}] + config_flags)
        expect(result['stdout'].strip).to eq(conn_info('ssh')[:user])
      end
    end

    it 'runs a task' do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[task run #{stdin_task} message=somemessage --configfile #{conf.path}] + config_flags)
        expect(result['message'].strip).to eq("somemessage")
      end
    end
  end
end
