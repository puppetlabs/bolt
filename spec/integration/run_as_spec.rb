# frozen_string_literal: true

require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when running a plan using run_as", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/run_as') }
  let(:uri) { conn_uri('ssh', include_password: true) }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }
  let(:config_flags) { %W[--no-host-key-check --format json --modulepath #{modulepath}] }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  def run_plan(plan, params)
    run_cli(['plan', 'run', plan, "--params", params.to_json] + config_flags)
  end

  context 'when using CLI options' do
    let(:config_flags) { %W[--no-host-key-check --format json --sudo-password #{password} --modulepath #{modulepath}] }
    let(:non_root_flags) {
      %W[-u bolt -p bolt --no-host-key-check --format json --sudo-password bolt --modulepath #{modulepath}]
    }

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

    it 'runs a plan as root passing in non-root user' do
      non_root = 'test'
      params = { target: uri, user: non_root }
      output = run_plan('test::run_as_user', params)
      parsed = JSON.parse(output)[0]
      expect(parsed['result']['stdout']).to eq("#{non_root}\n")
      expect(parsed['status']).to eq('success')
      expect(parsed['result']['exit_code']).to eq(0)
    end

    it 'runs a plan as a non-root user passing in a non-root user' do
      non_root = 'test'
      params = { target: uri, user: non_root }.to_json
      output = run_cli(['plan', 'run', 'test::run_as_user', "--params", params] + non_root_flags)
      parsed = JSON.parse(output)[0]
      expect(parsed['result']['stdout']).to eq("#{non_root}\n")
      expect(parsed['status']).to eq('success')
      expect(parsed['result']['exit_code']).to eq(0)
    end
  end
end
