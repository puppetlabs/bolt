require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when running a plan using run_as", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/run_as') }
  let(:uri) { conn_uri('ssh', true) }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }
  let(:config_flags) { %W[--insecure --format json --modulepath #{modulepath}] }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  def run_plan(plan, params)
    run_cli(['plan', 'run', plan, "--params", params.to_json] + config_flags)
  end

  context 'when using CLI options' do
    let(:config_flags) { %W[--insecure --format json --sudo-password #{password} --modulepath #{modulepath}] }

    it 'runs sudo when specified' do
      params = { target: uri }.to_json
      output = run_cli(['plan', 'run', 'test::id', "--params", params] + config_flags)
      expect(JSON.parse(output)).to eq(%W[#{user}\n root\n #{user}\n root\n #{user}\n root\n])
    end

    it 'runs sudo within a plan when specified' do
      params = { target: uri }.to_json
      output = run_cli(['plan', 'run', 'test::incept', "--params", params] + config_flags)
      expect(JSON.parse(output)).to eq(%W[#{user}\n root\n #{user}\n root\n #{user}\n root\n])
    end

    it 'runs sudo within a plan when specified' do
      params = { target: uri }.to_json
      output = run_cli(['plan', 'run', 'test::except', "--params", params] + config_flags)
      expect(JSON.parse(output)).to eq(%W[root\n root\n root\n root\n root\n root\n])
    end
  end
end
