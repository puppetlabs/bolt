# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'logging'

describe "when logging executor activity", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:echo_plan) { "sample::single_task" }
  let(:without_default_plan) { "logging::without_default" }
  let(:uri) { conn_uri('ssh', include_password: true) }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }
  let(:log_level) { :info }
  let(:lines) { @log_output.readlines }

  let(:config_flags) {
    %W[--targets #{uri} --no-host-key-check --format json --modulepath #{modulepath} --password #{password}]
  }

  before :each do
    @log_output.level = log_level
  end

  after :each do
    @log_output.level = :all
  end

  it 'logs the start and end of a plan' do
    result = run_cli_json(%W[plan run #{echo_plan} description=somemessage] + config_flags)
    expect(lines).to include(match(/INFO.*Starting: plan #{echo_plan}/))
    expect(lines).to include(match(/INFO.*Finished: plan #{echo_plan}/))
    expect(result[0]['value']['_output'].strip).to match(/hi there/)
  end

  it 'does not error if the default log file cannot be written' do
    expect(FileUtils).to receive(:touch).with(/bolt-debug\.log/).and_raise(Errno::EACCES)
    expect { run_cli(%W[command run #{whoami}] + config_flags) }
      .not_to raise_error
  end

  context 'with misconfigured ssh-command' do
    let(:log_level) { :warn }
    let(:conn) { conn_info('ssh') }
    let(:second_uri) { [conn[:second_user], ':', conn[:second_pw], '@', conn[:host], ':', conn[:port]].join }
    let(:config_flags) {
      %W[--targets #{uri},#{second_uri} --no-host-key-check --modulepath #{modulepath} --ssh-command ssh]
    }

    it 'only warns once with warn_once' do
      Dir.mktmpdir do |tmpdir|
        allow(Bolt::Config).to receive(:user_path).and_return(Pathname.new(File.join(tmpdir, 'bolt')))
        run_cli_json(%W[command run #{whoami}] + config_flags)
        expect(lines).to eq(["  WARN  Bolt::Logger : native-ssh must be true to use ssh-command\n"])
      end
    end
  end

  it 'logs node-level details for a command' do
    result = run_cli_json(%W[command run #{whoami}] + config_flags)
    expect(lines).to include(match(/Starting: command '#{whoami}'/))
    expect(lines).to include(match(/Running command '#{whoami}'/))
    expect(lines).to include(match(/#{conn_info('ssh')[:user]}/))
    expect(lines).to include(match(/Finished: command '#{whoami}'/))
    expect(result['items'][0]['value']['stdout'].strip).to eq(conn_info('ssh')[:user])
  end

  it 'logs node-level details for a task' do
    result = run_cli_json(%W[task run #{stdin_task} message=somemessage] + config_flags)
    expect(lines).to include(match(/Starting: task #{stdin_task}/))
    expect(lines).to include(match(/Running task #{stdin_task} with/))
    expect(lines).to include(match(/somemessage/))
    expect(lines).to include(match(/Finished: task #{stdin_task}/))
    expect(result['items'][0]['value']['message'].strip).to eq('somemessage')
  end

  it 'logs node-level details for a plan' do
    result = run_cli_json(%W[plan run #{echo_plan}] + config_flags)
    expect(lines).to include(match(/INFO.*Starting: plan #{echo_plan}/))
    expect(lines).to include(match(/Starting: task sample::echo/))
    expect(lines).to include(match(/Running task sample::echo with/))
    expect(lines).to include(match(/hi there/))
    expect(lines).to include(match(/Finished: task sample::echo/))
    expect(lines).to include(match(/INFO.*Finished: plan #{echo_plan}/))
    expect(result[0]['value']['_output'].strip).to match(/hi there/)
  end

  it 'logs node-level details when without_default_logging is set in a plan' do
    run_cli_json(%W[plan run #{without_default_plan}] + config_flags)
    expect(lines).to include(match(/INFO.*Starting: plan #{without_default_plan}/))
    expect(lines).to include(match(/Starting: task logging::echo/))
    expect(lines).to include(match(/Running task logging::echo with/))
    expect(lines).to include(match(/hi there/))
    expect(lines).to include(match(/Finished: task logging::echo/))
    expect(lines).to include(match(/INFO.*Finished: plan #{without_default_plan}/))
  end
end
