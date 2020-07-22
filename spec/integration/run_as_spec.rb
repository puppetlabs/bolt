# frozen_string_literal: true

require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "when running a plan using run_as", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/run_as') }
  let(:uri) { conn_uri('ssh', include_password: true) }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }
  let(:non_existent_user) { 'foo' }
  let(:config_flags) { %W[--no-host-key-check --format json --sudo-password #{password} --modulepath #{modulepath}] }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  def run_plan(plan, params)
    run_cli(['plan', 'run', plan, "--params", params.to_json] + config_flags)
  end

  it 'runs sudo when specified' do
    output = run_plan('test::id', target: uri)
    expect(JSON.parse(output)).to eq(%W[#{user}\n root\n #{user}\n root\n #{user}\n root\n])
  end

  context 'when passing environment variables' do
    let(:modulepath) { File.join(__dir__, '../fixtures/modules') }

    it 'correctly passes environment variables to a task' do
      output = run_cli_json(%W[task run sample message=tacos -t #{uri}] + config_flags)
      expect(output['items'].first['value']['_output'].strip).to eq('tacos')
    end

    it 'correctly passes environment variables specified in a plan' do
      output = run_cli_json(%W[plan run env_var::command -t #{uri} user=root] + config_flags).first
      expect(output['value']['stdout'].strip).to eq('and guacamole')
    end
  end

  it 'runs sudo within a plan when specified' do
    output = run_plan('test::incept', target: uri)
    expect(JSON.parse(output)).to eq(%W[#{user}\n root\n #{user}\n root\n #{user}\n root\n])
  end

  it 'runs sudo within a plan when specified' do
    output = run_plan('test::except', target: uri)
    expect(JSON.parse(output)).to eq(%W[root\n root\n root\n root\n root\n root\n])
  end

  it 'runs a plan as root passing in non-root user' do
    non_root = 'test'
    output = run_plan('test::run_as_user', target: uri, user: non_root)
    parsed = JSON.parse(output)[0]
    expect(parsed['value']['stdout']).to eq("#{non_root}\n")
    expect(parsed['status']).to eq('success')
    expect(parsed['value']['exit_code']).to eq(0)
  end

  context 'as a non-root user' do
    let(:config_flags) {
      %W[-u #{user} -p #{password} --no-host-key-check --format json --sudo-password bolt --modulepath #{modulepath}]
    }

    it 'runs a plan as a non-root user passing in a non-root user' do
      non_root = 'test'
      output = run_plan('test::run_as_user', target: uri, user: non_root)
      parsed = JSON.parse(output)[0]
      expect(parsed['value']['stdout']).to eq("#{non_root}\n")
      expect(parsed['status']).to eq('success')
      expect(parsed['value']['exit_code']).to eq(0)
    end
  end

  context 'when run-as is specified on cli or config' do
    let(:config_flags) {
      %W[-u #{user} -p #{password} --no-host-key-check --format json
         --sudo-password #{password} --modulepath #{modulepath} --run_as #{non_existent_user}]
    }

    it 'runs a plan containing run_* functions with user specified by _run_as taking priority' do
      run_as_config = { 'transport' => 'ssh', 'ssh' => { 'run-as' => non_existent_user.to_s } }
      with_tempfile_containing('conf', YAML.dump(run_as_config)) do |conf|
        non_root = 'test'
        params = { target: uri, user: non_root }
        config_array = config_flags + %W[--configfile #{conf.path}]
        output = run_cli(['plan', 'run', 'test::run_as_user', "--params", params.to_json] + config_array)
        parsed = JSON.parse(output)[0]
        expect(parsed['value']['stdout']).to eq("#{non_root}\n")
        expect(parsed['status']).to eq('success')
        expect(parsed['value']['exit_code']).to eq(0)
      end
    end
  end
end
