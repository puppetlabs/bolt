# frozen_string_literal: true

require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "when running a plan that manipulates an execution result", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:uri) { conn_uri('ssh', include_password: true) }
  let(:config_flags) { %W[--no-host-key-check --format json --modulepath #{modulepath}] }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  def run_plan(plan, params)
    run_cli(['plan', 'run', plan, "--params", params.to_json] + config_flags)
  end

  context 'when using CLI options' do
    let(:config_flags) { %W[--no-host-key-check --format json --modulepath #{modulepath}] }

    it 'returns true on success' do
      params = { target: uri }.to_json
      output = run_cli(['plan', 'run', 'results::test_methods', "--params", params] + config_flags)
      expect(output.strip).to eq('true')
    end

    it 'returns false on failure' do
      params = { target: uri, fail: true }.to_json
      output = run_cli(['plan', 'run', 'results::test_methods', "--params", params] + config_flags)
      expect(output.strip).to eq('false')
    end

    context 'filters result sets' do
      it 'includes target when filter is true' do
        params = { target: uri }.to_json
        run_cli(['plan', 'run', 'results::test_methods', "--params", params] + config_flags)
        expect(@log_output.readlines)
          .to include("NOTICE  Puppet : Filtered set: [Target('ssh://bolt:bolt@localhost:20022', {})]\n")
      end

      it 'excludes target when filter is false' do
        params = { target: uri, fail: true }.to_json
        run_cli(['plan', 'run', 'results::test_methods', "--params", params] + config_flags)
        expect(@log_output.readlines).to include("NOTICE  Puppet : Filtered set: []\n")
      end
    end

    it 'exposes errrors for results' do
      params = { target: uri }.to_json
      output = run_cli(['plan', 'run', 'results::test_error', "--params", params] + config_flags)
      expect(output.strip).to eq('"The task failed with exit code 1:\n"')
    end
  end
end
