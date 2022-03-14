# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/util'

describe "catch_errors", ssh: true do
  include BoltSpec::Integration
  include BoltSpec::Files
  include BoltSpec::Conn

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:modulepath) { [fixtures_path('modules'), fixtures_path('apply')].join(File::PATH_SEPARATOR) }
  let(:target) { conn_uri('ssh', include_password: true) }

  let(:transport_flags) { ['--no-host-key-check'] }

  let(:config_flags) {
    ['--format', 'json',
     '--project', fixtures_path('configs', 'empty'),
     '--modulepath', modulepath,
     '--targets', target] + transport_flags
  }
  let(:plan) { "catch_errors" }

  it 'catches an error and continues' do
    run_cli(%w[plan run catch_errors] + config_flags)
    output = @log_output.readlines
    expect(output).to include(/Puppet : Step 1/)
  end

  it 'returns a ResultSet' do
    result = run_cli_json(%W[plan run #{plan}] + config_flags)
    error = result['details']['result_set'].first['value']['_error']
    expect(error['kind']).to eq('puppetlabs.tasks/task-error')
    expect(error['msg']).to match(/failed with exit code 1/)
  end

  it 'returns the output if there are no errors' do
    params = { fail: false }.to_json
    result = run_cli_json(%W[plan run #{plan} --params #{params}] + config_flags).first
    expect(result['status']).to eq('success')
    expect(result['value']['stdout'].strip).to eq("Unepic unfailure")
  end

  context "with typed errors" do
    # Plan returns a hash { 'error' => error, 'msg' => "Success" }
    let(:plan) { "catch_errors::typed" }

    it 'returns the error if it matches the type' do
      params = { fail_task: true,
                 errors: ['bolt/run-failure'] }.to_json
      result = run_cli_json(%W[plan run #{plan} --params #{params}] + config_flags)
      expect(result['error']['kind']).to eq('bolt/run-failure')
      expect(result['msg']).to eq("Success")
      expect(result).not_to include('kind')

      # Verify that the plan continued
      output = @log_output.readlines
      expect(output).to include(/Puppet : Step 2/)
    end

    it 'returns the error if it matches the second type in the array' do
      params = { fail_plan: true,
                 errors: ['bolt/run-failure',
                          'bolt/apply-failure'] }.to_json
      result = run_cli_json(%W[plan run #{plan} --params #{params}] + config_flags)
      expect(result['error']['kind']).to eq('bolt/apply-failure')
      expect(result).not_to include('kind')
    end

    it 'fails the plan if the error is not in the type list' do
      params = { fail_task: true,
                 errors: ['bolt/fake-error'] }.to_json
      result = run_cli_json(%W[plan run #{plan} --params #{params}] + config_flags)

      expect(result).to include('kind')
    end
  end

  context "when breaking" do
    let(:plan) { "catch_errors::break" }
    it "breaks from enumeration" do
      params = { list: %w[firstcomment b c] }
      result = run_cli_json(%W[plan run #{plan} --params #{params.to_json}] +
                            config_flags)
      expect(result).to eq("Break the chain")
      output = @log_output.readlines
      expect(output).to include(/Puppet : firstcomment/)
      expect(output).not_to include(/Out of bounds/)
    end
  end

  context "when returning" do
    let(:plan) { "catch_errors::return" }

    it "returns from the plan" do
      result = run_cli_json(%W[plan run #{plan}] + config_flags)
      expect(result).to include("You can return a product for up to 30 days")
      output = @log_output.readlines
      expect(output).not_to include(/Don't go here/)
    end
  end
end
