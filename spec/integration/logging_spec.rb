# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'
require 'logging'

describe "when logging executor activity", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { fixtures_path('modules') }
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
        expect(lines.count { |line| /WARN.*native-ssh must be true to use ssh-command/ =~ line }).to eq(1)
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

describe 'suppressing warnings' do
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:base_config) { { 'log' => { 'bolt-debug.log' => 'disable' } } }
  let(:name)        { 'bolt' }

  around(:each) do |example|
    with_project(name, config: config) do |project|
      @project = project
      example.run
    end
  end

  context 'with disable-warnings configured' do
    before(:each) do
      FileUtils.mkdir_p(@project.path + 'modules' + name)
    end

    context 'without matching ID' do
      let(:config) { base_config.merge('disable-warnings' => ['foobar']) }

      it 'does not suppress warnings' do
        run_cli_json(%w[task show], project: @project)

        expect(@log_output.readlines).to include(
          /WARN.*The project 'bolt' shadows an existing module of the same name/
        )
      end
    end

    context 'with matching ID' do
      let(:config) { base_config.merge('disable-warnings' => ['project_shadows_module']) }

      it 'suppresses warnings' do
        run_cli_json(%w[task show], project: @project)

        expect(@log_output.readlines).not_to include(
          /WARN.*The project 'bolt' shadows an existing module of the same name/
        )
      end
    end
  end
end

shared_examples 'streaming output' do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:lines)         { @log_output.readlines }
  let(:logger)        { Bolt::Logger.logger(:stream) }
  let(:rootuser)      { 'root' }
  let(:run_as_flags)  { config_flags + %W[--run-as #{rootuser} --sudo-password #{pw}] }

  around :each do |example|
    with_project(config: config) do |project|
      @project = project
      example.run
    end
  end

  context 'with streaming enabled' do
    let(:config) {
      { 'modulepath' => fixtures_path('modules'),
        'stream' => true }
    }

    before :each do
      allow(Bolt::Logger).to receive(:logger).with(any_args).and_call_original
      expect(Bolt::Logger).to receive(:logger).with(:stream).and_return(logger)
      # Don't actually print logs
      allow(logger).to receive(:warn)
    end

    it 'streams stdout to the console' do
      expect(logger).to receive(:warn).with(/\[#{uri}\] out: #{user}/)
      run_cli(%W[command run #{whoami} -t #{uri}] + config_flags, project: @project)
    end

    it 'streams stderr to the console' do
      expect(logger).to receive(:warn).with(/\[#{uri}\] err: error/)
      run_cli(%W[command run #{err_cmd} -t #{uri}] + config_flags, project: @project)
    end

    it 'streams when using run-as', ssh: true do
      expect(logger).to receive(:warn).with(/\[#{uri}\] out: #{rootuser}/)
      run_cli(%W[command run #{whoami} -t #{uri}] + run_as_flags, project: @project)
    end

    it 'formats multi-line messages correctly' do
      expected = <<~OUTPUT
      [#{uri}] out: In like a lion
      [#{uri}] out: Out like a lamb
      OUTPUT
      expect(logger).to receive(:warn).with(expected.chomp)
      run_cli(%W[task run sample::multiline -t #{uri}] + config_flags, project: @project)
    end

    it 'does not print streaming logs to log files' do
      run_cli(%W[command run #{whoami} -t #{uri}] + config_flags, project: @project)
      expect(File.read(File.join(@project.path, 'bolt-debug.log'))).not_to include("[#{uri}] out: bolt")
    end
  end

  context 'with streaming disabled' do
    let(:config) { {} }

    it 'does not print streaming logs' do
      allow(Bolt::Logger).to receive(:logger).with(any_args).and_call_original
      expect(Bolt::Logger).not_to receive(:logger).with(:stream)
      run_cli(%W[command run #{whoami} -t #{uri}] + config_flags, project: @project)
    end
  end
end

describe 'streaming output over SSH', ssh: true do
  include BoltSpec::Conn

  let(:uri)           { conn_uri('ssh') }
  let(:pw)            { conn_info('ssh')[:password] }
  let(:whoami)        { 'whoami' }
  let(:user)          { conn_info('ssh')[:user] }
  let(:err_cmd)       { "echo 'error' 1>&2" }
  let(:config_flags)  { %W[--no-host-key-check --password #{pw}] }

  include_examples 'streaming output'
end

describe 'streaming output over WinRM', winrm: true do
  include BoltSpec::Conn

  let(:uri)           { conn_uri('winrm') }
  let(:pw)            { conn_info('winrm')[:password] }
  let(:user)          { conn_info('winrm')[:user] }
  let(:whoami)        { '$env:UserName' }
  let(:err_cmd)       { '$host.ui.WriteErrorLine("error")' }
  let(:config_flags)  { %W[--no-ssl --no-ssl-verify --connect-timeout 120 --password #{pw}] }

  include_examples 'streaming output'
end
