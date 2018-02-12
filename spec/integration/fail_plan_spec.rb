require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "When a plan fails" do
  include BoltSpec::Integration
  include BoltSpec::Config
  include BoltSpec::Conn

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:modulepath) { fixture_path('modules') }
  let(:config_flags) {
    ['--format', 'json',
     '--configfile', fixture_path('configs', 'empty.yml'),
     '--modulepath', modulepath,
     '--no-host-key-check']
  }
  let(:target) { conn_uri('ssh', true) }

  it 'returns the error object' do
    result = run_cli_json(['plan', 'run', 'error::args'] + config_flags, rescue_exec: true)
    if error_support
      expect(result).to eq('msg' => 'oops',
                           'kind' => 'test/oops',
                           'details' => { 'some' => 'info' })
    else
      expect(result['msg']).to match(/oops/)
      expect(result['kind']).to eq('bolt/cli-error')
    end
  end

  it 'returns the error object' do
    result = run_cli_json(['plan', 'run', 'error::err'] + config_flags, rescue_exec: true)
    if error_support
      expect(result).to eq('msg' => 'oops',
                           'kind' => 'test/oops',
                           'details' => { 'some' => 'info' })
    else
      expect(result['msg']).to match(/oops/)
      expect(result['kind']).to eq('bolt/cli-error')
    end
  end

  it 'catches plan failures' do
    if error_support
      result = run_cli_json(['plan', 'run', 'error::catch_plan'] + config_flags)
      expect(result).to eq('msg' => 'oops',
                           'kind' => 'test/oops',
                           'details' => { 'some' => 'info' })
    else
      result = run_cli_json(['plan', 'run', 'error::catch_plan'] + config_flags, rescue_exec: true)
      expect(result['msg']).to match(/oops/)
    end
  end

  it 'catches run failures', ssh: true do
    if error_support
      result = run_cli_json(['plan', 'run', 'error::catch_plan_run', "target=#{target}"] + config_flags)
      expect(result).to eq("kind" => "puppetlabs.tasks/task-error",
                           "issue_code" => "TASK_ERROR",
                           "msg" => "The task failed with exit code 1",
                           "details" => { "exit_code" => 1 })
    else
      result = run_cli_json(['plan', 'run', 'error::catch_plan_run', "target=#{target}"] + config_flags,
                            rescue_exec: true)
      expect(result['msg']).to match(/error::fail/)
    end
  end

  it 'outputs nested errors' do
    if error_support
      result = run_cli_json(['plan', 'run', 'error::nested'] + config_flags)
      expect(result).to eq('error' => [{
                             'msg' => 'oops',
                             'kind' => 'test/oops',
                             'details' => { 'some' => 'info' }
                           }])
    end
  end
end
