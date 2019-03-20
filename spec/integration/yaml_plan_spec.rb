# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "running YAML plans", ssh: true do
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
  let(:target) { conn_uri('ssh', include_password: true) }

  def run_plan(plan_name, params = {})
    result = run_cli(['plan', 'run', plan_name, '--params', params.to_json] + config_flags,
                     outputter: Bolt::Outputter::JSON)
    JSON.parse(result)
  end

  it 'runs a command' do
    result = run_plan('yaml::command', nodes: target)

    expect(result.first['node']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['result']).to eq("stdout" => "hello world\n", "stderr" => "", "exit_code" => 0)
  end

  it 'runs a task' do
    result = run_plan('yaml::task', nodes: target)

    expect(result.first['node']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['result']).to eq('_output' => "hello world\n")
  end

  it 'runs a script' do
    result = run_plan('yaml::script', nodes: target)

    expect(result.first['node']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['result']['stdout']).to eq("foo bar baz\n")
  end

  it 'uploads a file' do
    result = run_plan('yaml::upload', nodes: target)

    expect(result.first['node']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['result']['_output']).to match(/Uploaded .*test.sh/)
  end

  it 'passes information between steps' do
    result = run_plan('yaml::param_passing')

    expect(result).to eq([24, 36, 60, "60"])
  end
end
