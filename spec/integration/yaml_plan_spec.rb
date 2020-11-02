# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/logger'

describe "running YAML plans", ssh: true do
  include BoltSpec::Integration
  include BoltSpec::Config
  include BoltSpec::Conn
  include BoltSpec::Logger

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }
  # Don't print error messages to the console
  before(:each) { allow($stdout).to receive(:puts) }

  let(:modulepath) { fixture_path('modules') }
  let(:password) { conn_info('ssh')[:password] }
  let(:config_flags) {
    ['--format', 'json',
     '--configfile', fixture_path('configs', 'empty.yml'),
     '--modulepath', modulepath,
     '--run-as', 'root',
     '--sudo-password', password,
     '--no-host-key-check']
  }
  let(:target) { conn_uri('ssh', include_password: true) }

  def run_plan(plan_name, params = {})
    result = run_cli(['plan', 'run', plan_name, '--params', params.to_json] + config_flags,
                     outputter: Bolt::Outputter::JSON)
    JSON.parse(result)
  end

  it 'runs a command' do
    result = run_plan('yaml::command', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['value']).to eq("stdout" => "hello world\n", "stderr" => "", "exit_code" => 0)
  end

  it 'runs a task' do
    result = run_plan('yaml::task', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['value']).to eq('_output' => "hello world\n")
  end

  it 'runs a script' do
    result = run_plan('yaml::script', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['value']['stdout']).to eq("foo bar baz\n")
  end

  it 'uploads a file' do
    result = run_plan('yaml::upload', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['value']['_output']).to match(/Uploaded .*test.sh/)
  end

  it 'downloads a file' do
    Dir.mktmpdir(nil, Dir.pwd) do |dir|
      # download_file only accepts relative paths for the destination, so force the
      # project to be the tmpdir so the test doesn't accidentally download a file to
      # the user's default downloads directory
      allow_any_instance_of(Bolt::Project).to receive(:downloads).and_return(Pathname.new(dir))

      result = run_plan('yaml::download', targets: target, destination: 'foo')

      expect(result.first['target']).to eq(target)
      expect(result.first['status']).to eq('success')
      expect(result.first['value']['_output']).to match(%r{Downloaded .*/etc/ssh/ssh_config})
    end
  end

  it 'runs another plan' do
    result = run_plan('yaml::delegate', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')
    expect(result.first['value']).to eq('_output' => "hello world\n")
  end

  it 'applies resources' do
    result = run_plan('yaml::resources', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')

    resources = result.first['value']['report']['resource_statuses']

    expect(resources['Notify[hello world]']['changed']).to eq(true)
    expect(resources['Notify[goodbye]']['changed']).to eq(true)
  end

  it 'skips remaining resources if one resource fails' do
    result = run_plan('yaml::resource_failure', targets: target)

    expect(result['kind']).to eq('bolt/apply-failure')
    target_result = result.dig('details', 'result_set').first
    expect(target_result['target']).to eq(target)
    expect(target_result['status']).to eq('failure')

    expect(target_result.dig('value', '_error', 'kind')).to eq('bolt/resource-failure')

    resources = target_result['value']['report']['resource_statuses']

    # The file resource will fail so the second notify is skipped
    expect(resources['Notify[hello world]']['changed']).to eq(true)
    expect(resources['File[/tmp/foo/bar/baz]']['failed']).to eq(true)
    expect(resources['Notify[goodbye]']['changed']).to eq(false)
    expect(resources['Notify[goodbye]']['skipped']).to eq(true)
  end

  it 'applies an empty catalog if no resources are specified' do
    result = run_plan('yaml::empty_resources', targets: target)

    expect(result.first['target']).to eq(target)
    expect(result.first['status']).to eq('success')

    resources = result.first['value']['report']['resource_statuses']
    expect(resources).to be_empty
  end

  it 'does not expose its own variables to a sub-plan' do
    result = run_plan('yaml::plan_with_isolated_subplan', message: 'hello world')

    expect(result['msg']).to match(/Unknown variable/)
  end

  it 'does not leak variables back into the calling plan' do
    result = run_plan('yaml::plan_isolated_from_subplan')

    expect(result['msg']).to match(/Unknown variable/)
  end

  it 'fails when embedded puppet code cannot be parsed' do
    result = run_plan('yaml::bad_puppet')

    expect(result['kind']).to eq("bolt/invalid-plan")
    expect(result['msg']).to match(/Parse error in step "x_fail":/)
  end

  it 'fails gracefully when the yaml plan contains errors' do
    result = run_plan('yaml::invalid', targets: target)

    expect(result['kind']).to eq("bolt/pal-error")
    expect(result['msg']).to match(/did not find expected '-' indicator.*at line 10 column 5/)
  end

  it 'passes information between steps' do
    result = run_plan('yaml::param_passing')

    expect(result).to eq([24, 36, 60, "60"])
  end

  # TODO: Remove when 'target' parameter is removed
  it "warns when using deprecated 'target' parameter" do
    stub_logger
    allow(Logging).to receive(:logger).and_return(mock_logger)
    allow(Puppet::Util::Log).to receive(:newdestination).with(mock_logger)
    allow(mock_logger).to receive(:notice)
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:warn)
      .with("No project name is specified in bolt-project.yaml. Project-level content will not be available.")
    allow(mock_logger).to receive(:warn)
      .with("bolt-project.yaml contains valid config keys, bolt.yaml will be ignored")

    expect(Bolt::Logger).to receive(:deprecation_warning).with(anything, /Use the 'targets' parameter instead./)

    run_plan('yaml::target_param', targets: target)
  end

  # TODO: Remove when 'target' parameter is removed
  it "prefers 'targets' parameter over 'target'" do
    result = run_plan('yaml::target_preference', targets: target)
    expect(result.first['target']).to eq(target)
  end

  context 'evaluating Puppet code' do
    it 'includes file and line number for errors in bare strings' do
      result = run_plan('yaml::eval_error_bare_string')

      expect(result['kind']).to eq('bolt/evaluation-error')
      expect(result['details']['file']).to match(/eval_error_bare_string\.yaml/)
      expect(result['details']['line']).to eq(3)
    end

    it 'includes file and line number for errors in scalar literals' do
      result = run_plan('yaml::eval_error_scalar_literal')

      expect(result['kind']).to eq('bolt/evaluation-error')
      expect(result['details']['file']).to match(/eval_error_scalar_literal\.yaml/)
      expect(result['details']['line']).to eq(5)
    end

    it 'includes file and line number for errors in nested sub plans' do
      result = run_plan('yaml::eval_error_sub_plan')

      expect(result['kind']).to eq('bolt/evaluation-error')
      expect(result['details']['file']).to match(/eval_error_bare_string\.yaml/)
      expect(result['details']['line']).to eq(3)
    end
  end
end
