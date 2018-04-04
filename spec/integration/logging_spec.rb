# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/integration'
require 'bolt/cli'
require 'logging'

describe "when logging executor activity", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:echo_plan) { "sample::single_task" }
  let(:uri) { conn_uri('ssh') }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }
  let(:log_level) { :notice }

  let(:config_flags) {
    %W[--nodes #{uri} --no-host-key-check --format json --modulepath #{modulepath} --password #{password}]
  }

  before :each do
    @log_output.level = log_level
  end

  after :each do
    @log_output.level = :all
  end

  it 'does not log with a command' do
    result = run_cli_json(%W[command run #{whoami}] + config_flags)
    expect(@log_output.readline).to be_nil
    expect(result['items'][0]['result']['stdout'].strip).to eq(conn_info('ssh')[:user])
  end

  it 'does not log with a task' do
    result = run_cli_json(%W[task run #{stdin_task} message=somemessage] + config_flags)
    expect(@log_output.readline).to be_nil
    expect(result['items'][0]['result']['message'].strip).to eq('somemessage')
  end

  it 'logs with a plan that includes a description' do
    result = run_cli_json(%W[plan run #{echo_plan} description=somemessage] + config_flags)
    expect(@log_output.readline).to match(/Starting: somemessage on/)
    expect(@log_output.readline).to match(/Finished: somemessage on/)
    expect(result[0]['result']['_output'].strip).to match(/hi there/)
  end

  context 'with verbose logging' do
    let(:log_level) { :info }

    it 'logs actions with a command' do
      result = run_cli_json(%W[command run #{whoami}] + config_flags)
      expect(@log_output.readline).to match(/Starting: command '#{whoami}'/)
      expect(@log_output.readline).to match(/Running command '#{whoami}'/)
      expect(@log_output.readline).to match(/#{conn_info('ssh')[:user]}/)
      expect(@log_output.readline).to match(/Finished: command '#{whoami}'/)
      expect(result['items'][0]['result']['stdout'].strip).to eq(conn_info('ssh')[:user])
    end

    it 'logs actions with a task' do
      result = run_cli_json(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(@log_output.readline).to match(/Starting: task #{stdin_task}/)
      expect(@log_output.readline).to match(/Running task #{stdin_task} with/)
      expect(@log_output.readline).to match(/somemessage/)
      expect(@log_output.readline).to match(/Finished: task #{stdin_task}/)
      expect(result['items'][0]['result']['message'].strip).to eq('somemessage')
    end

    it 'logs extra with a plan' do
      result = run_cli_json(%W[plan run #{echo_plan}] + config_flags)
      expect(@log_output.readline).to match(/Starting: task sample::echo/)
      expect(@log_output.readline).to match(/Running task sample::echo with/)
      expect(@log_output.readline).to match(/hi there/)
      expect(@log_output.readline).to match(/Finished: task sample::echo/)
      expect(result[0]['result']['_output'].strip).to match(/hi there/)
    end
  end
end
