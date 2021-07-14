# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "caching tasks" do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:project) { @project }
  let(:mdpath)  { fixtures_path('modules') }
  let(:config)  { { 'modulepath' => mdpath } }
  let(:flags)   { %W[--project #{project.path}] }

  around :each do |example|
    with_project(config: config) do |project|
      @project = project
      example.run
    end
  end

  it 'caches tasks when generating types' do
    env_var_task = { "env_var::get_var" =>
                    { "name" => "env_var::get_var",
                      "files" =>
                    [{ "name" => "get_var.sh",
                       "path" => fixtures_path('modules', 'env_var', 'tasks', 'get_var.sh'),
                       "mtime" => /.*/ }],
                      "metadata" => {} } }
    expect(Dir.children(project.path)).not_to include('.task_cache.json')

    run_cli(%w[module generate-types] + flags)
    expect(Dir.children(project.path)).to include('.task_cache.json')
    cache = JSON.parse(File.read(project.task_cache_file))
    expect(cache).to include(env_var_task)
  end

  it 'does not update the cache if local tasks have not been modified' do
    run_cli(%w[module generate-types] + flags)
    original_mtime = File.mtime(project.task_cache_file)
    run_cli(%w[task show] + flags)
    expect(original_mtime).to eq(File.mtime(project.task_cache_file))
  end
end
