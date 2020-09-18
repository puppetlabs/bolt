# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/integration'

describe "When loading content", ssh: true do
  include BoltSpec::Config
  include BoltSpec::Conn
  include BoltSpec::Integration

  let(:local) { Bolt::Project.create_project(File.join(__dir__, '../fixtures/projects/local'), 'local') }
  let(:embedded) { fixture_path('projects/embedded') }
  let(:target) { conn_uri('ssh') }
  let(:config_flags) { %W[--no-host-key-check --password #{conn_info('ssh')[:password]}] }

  it "migrates project config files to the newest version" do
    allow($stdin).to receive(:tty?).and_return(true)
    allow($stderr).to receive(:puts)
    allow(Bolt::Util).to receive(:prompt_yes_no).and_return(true)

    Dir.mktmpdir do |project|
      config = { 'color' => true, 'ssh' => { 'port' => 23 } }
      conf_file = File.join(project, 'bolt.yaml')
      project_file = File.join(project, 'bolt-project.yaml')
      inv_file = File.join(project, 'inventory.yaml')

      File.write(conf_file, config.to_yaml)
      run_cli(%W[project migrate --project #{project}])

      expect(File.exist?(conf_file)).not_to be
      expect(File.exist?(project_file)).to be
      expect(YAML.load_file(project_file)).to eq({ 'color' => true })
      expect(File.exist?(inv_file)).to be
      expect(YAML.load_file(inv_file)).to eq({ 'config' => { 'ssh' => { 'port' => 23 } } })
    end
  end

  it "loads plans from project level content" do
    result = run_cli_json(%W[plan run local -t #{target} --boltdir #{local.path}] + config_flags)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "loads plans from project when specified with --project" do
    result = run_cli_json(%W[plan run local -t #{target} --project #{local.path}] + config_flags)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "loads embedded plans from a project specified with --project" do
    result = run_cli_json(%W[plan show --project #{embedded}])
    expect(result['plans']).to include(['embedded'])
  end

  it "project level content can reference other modules" do
    result = run_cli_json(%W[task run local -t #{target}] + config_flags, project: local)
    expect(result["items"][0]["value"]["_output"].strip).to eq('polo')
  end

  it "runs plans namespaced with local project type" do
    result = run_cli_json(%W[plan run local -t #{target}] + config_flags, project: local)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "runs plans namespaced with embedded project type" do
    embedded = Bolt::Project.create_project(File.join(__dir__, '../fixtures/projects/embedded/Boltdir'), 'embedded')
    result = run_cli_json(%W[plan run embedded -t #{target}] + config_flags, project: embedded)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "runs plans namespaced to configured project name" do
    named = Bolt::Project.create_project(File.join(__dir__, '../fixtures/projects/named'), 'local')
    result = run_cli_json(%W[plan run test_project -t #{target}] + config_flags, project: named)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end
end
