# frozen_string_literal: true

require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "when running a plan that creates targets", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:uri) { conn_uri('ssh', include_password: true) }
  let(:info) { conn_info('ssh') }

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
            'target' => uri,
            'type' => 'task',
            'object' => 'results',
            'status' => 'success',
            'result' => {
              '_output' => "hi\n"
            }
          }
        ]
      )
    end

    it 'only prints necessary info' do
      params = { user: info[:user],
                 password: info[:password],
                 port: info[:port],
                 host: info[:host] }.to_json
      run_cli(['plan', 'run', 'results::test_printing', "--params", params] + config_flags)
      logs = @log_output.readlines.join('')
      regex = Regexp.new(Regexp.quote('Connected to Target(\'localhost\', {"user"=>"bolt", "port"=>20022})'))
      expect(logs).to match(regex)
    end
  end
end
