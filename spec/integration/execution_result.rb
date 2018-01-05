require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when runnning over the ssh transport", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:uri) { conn_uri('ssh') }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }

  context 'when using CLI options' do
    let(:config_flags) { %W[--insecure --format json --modulepath #{modulepath}] }

    it 'returns true on success' do
      output = run_cli(['plan', 'run', 'results::test_methods', "target=#{uri}"] + config_flags)
      expect(output.strip).to eq('true')
    end
  end
end
