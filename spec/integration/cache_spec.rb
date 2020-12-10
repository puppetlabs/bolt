# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'caching plugins' do
  include BoltSpec::Config
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:project) { @project }
  let(:project_path) { @project.path }
  let(:inventory) { nil }
  let(:mpath) { fixture_path('plugin_modules') }
  let(:plan) do
    <<~PLAN
      plan cache_test() {
        return get_target('node1').user
      }
    PLAN
  end

  around(:each) do |example|
    with_project('cache_test', inventory: inventory) do |project|
      @project = project

      ENV['BOLT_TEST_PLUGIN_VALUE'] = 'player_one'
      if plan
        FileUtils.mkdir_p(File.join(project_path, 'plans'))
        File.write(File.join(project_path, 'plans', 'init.pp'), plan)
      end

      example.run
    end
  end

  context 'refreshing cache' do
    let(:plugin) {
      {
        '_plugin' => 'task',
        'task' => 'env_plugin::resolve_reference',
        '_cache' => { 'ttl' => 120 }
      }
    }

    let(:inventory) {
      { 'targets' => [
        { 'uri' => 'node1',
          'config' => {
            'ssh' => {
              'user' => plugin
            }
          } }
      ] }
    }

    it 'removes the existing cache file with --clear-cache' do
      run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      expect(JSON.parse(File.read(project.cache_file)).values.first)
        .to include({ 'result' => 'player_one' })

      ENV['BOLT_TEST_PLUGIN_VALUE'] = 'player_two'

      result = run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath} --clear-cache])
      expect(JSON.parse(result)).to eq('player_two')
    end

    it 'caches results' do
      run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      expect(JSON.parse(File.read(project.cache_file)).values.first)
        .to include({ 'result' => 'player_one' })

      ENV['BOLT_TEST_PLUGIN_VALUE'] = 'player_two'

      result = run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      expect(JSON.parse(result)).to eq('player_one')
    end

    context 'with a short ttl' do
      let(:plugin) {
        {
          '_plugin' => 'task',
          'task' => 'env_plugin::resolve_reference',
          '_cache' => { 'ttl' => 0 }
        }
      }

      it 'removes cache entries once the ttl has expired' do
        run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
        expect(JSON.parse(File.read(project.cache_file)).values.first)
          .to include({ 'result' => 'player_one' })
        ENV['BOLT_TEST_PLUGIN_VALUE'] = 'player_two'
        result = run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
        expect(JSON.parse(result)).to eq('player_two')
      end

      it 'removes cache entries even if the calling plugin is removed' do
        run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
        expect(JSON.parse(File.read(project.cache_file)).values.first)
          .to include({ 'result' => 'player_one' })
        FileUtils.rm_f(File.join(project_path, 'inventory.yaml'))
        result = run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
        expect(JSON.parse(result)).to eq(nil)
      end
    end
  end
end
