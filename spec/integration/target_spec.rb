require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when running a plan that manipulates an execution result", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:uri) { conn_uri('ssh', include_password: true) }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  context 'when using CLI options' do
    let(:config_flags) { %W[--no-host-key-check --format json --modulepath #{modulepath}] }

    it 'returns execution results' do
      params = { node: uri }.to_json
      output = run_cli(['plan', 'run', 'results::test_target', "--params", params] + config_flags)
      expect(JSON.parse(output)).to eq(
        [
          {
            'node' => uri,
            'status' => 'success',
            'result' => {
              '_output' => "hi\n"
            }
          }
        ]
      )
    end
  end
end
