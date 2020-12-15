# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "When loading content", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:local) { Bolt::Project.create_project(fixtures_path('projects', 'local'), 'local') }
  let(:embedded) { fixtures_path('projects/embedded') }
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
      expect(YAML.load_file(project_file)).to include({ 'color' => true })
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

  context 'filtering project content' do
    let(:project) { @project }

    let(:project_config) do
      {
        'modulepath' => File.join(__dir__, '../fixtures/modules'),
        'plans' => [
          'sample',
          'error::catch*'
        ],
        'tasks' => [
          'sample',
          'error::*'
        ]
      }
    end

    around(:each) do |example|
      with_project(config: project_config) do |project|
        @project = project
        example.run
      end
    end

    it 'filters plans by name and glob pattern' do
      result = run_cli_json(%w[plan show], project: project)

      expect(result['plans'].map(&:first)).to match_array([
                                                            'sample',
                                                            'error::catch_plan_run',
                                                            'error::catch_plan'
                                                          ])
    end

    it 'filters tasks by name and glob pattern' do
      result = run_cli_json(%w[task show], project: project)

      expect(result['tasks'].map(&:first)).to match_array([
                                                            'sample',
                                                            'error::fail',
                                                            'error::typed'
                                                          ])
    end
  end
end
