# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "with private plans" do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:modulepath) { fixtures_path('modules') }
  let(:yaml_plan) do
    { 'private' => true,
      'steps' => [
        { 'name' => 'print',
          'targets' => 'localhost',
          'command' => 'echo Initializing' }
      ] }
  end

  context 'with a private YAML plan' do
    it 'does not show the private plan in plan show output' do
      result = run_cli_json(%W[plan show -m #{modulepath}])
      plans = result['plans'].map(&:first)
      expect(plans).to include('facts')
      expect(plans).not_to include('private::yaml')
    end

    it 'shows the private plan in plan show <plan> output' do
      data = { "name" => "private::yaml",
               "description" => "A plan with a private key",
               "parameters" => {},
               "private" => true }
      result = run_cli_json(%W[plan show private::yaml -m #{modulepath}])
      expect(result).to include(data)
    end
  end

  context 'with a private Puppet plan' do
    it 'does not show the private plan in plan show output' do
      result = run_cli_json(%W[plan show -m #{modulepath}])
      plans = result['plans'].map(&:first)
      expect(plans).to include('facts')
      expect(plans).not_to include('private::puppet')
    end

    it 'shows the private plan in plan show <plan> output' do
      data = { "name" => "private::puppet",
               "description" => /A plan with a private key/,
               "parameters" => {},
               "private" => true }
      result = run_cli_json(%W[plan show private::puppet -m #{modulepath}])
      expect(result).to include(data)
    end

    context 'with a project' do
      let(:project)       { @project }
      let(:config_flags)  { %W[--project #{project.path}] }

      around :each do |example|
        with_project do |project|
          @project = project
          example.run
        end
      end

      it 'does not update the cache if local plans have not been modified' do
        run_cli(%w[module generate-types] + config_flags)
        original_mtime = File.mtime(project.plan_cache_file)
        run_cli(%w[plan show] + config_flags)
        expect(original_mtime).to eq(File.mtime(project.plan_cache_file))
      end

      it 'updates the cache for local plans if modified' do
        run_cli(%w[module generate-types] + config_flags)
        original_mtime = File.mtime(project.plan_cache_file)
        run_cli(%w[plan show] + config_flags)
        expect(original_mtime).to eq(File.mtime(project.plan_cache_file))
      end

      it 'does not update the cache if non-local plans are modified' do
      end
    end
  end

  context 'with a private task' do
    it 'does not show the private task in task show output' do
      result = run_cli_json(%W[task show -m #{modulepath}])
      expect(result['tasks']).to include(["facts", "Gather system facts"])
      expect(result['tasks']).not_to include(["private", "Private Task"])
    end

    it 'shows the private task in task show <task> output' do
      data = { "name" => "private",
               "metadata" => {
                 "name" => "Private Task", "description" => "Do not list this task", "private" => true
               } }
      result = run_cli_json(%W[task show private -m #{modulepath}])
      expect(result).to include(data)
    end
  end
end
