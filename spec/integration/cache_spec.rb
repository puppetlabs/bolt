# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'caching plugins' do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:project)       { @project }
  let(:project_path)  { @project.path }
  let(:inventory)     { nil }
  let(:user_env_var)  { 'BOLT_USER_PLUGIN_VALUE' }
  let(:tmpdir_env_var)  { 'BOLT_PORT_PLUGIN_VALUE' }
  let(:mpath) { fixtures_path('plugin_modules') }
  let(:plan) do
    <<~PLAN
      plan cache_test() {
        return get_target('node1').user
      }
    PLAN
  end

  def plugin(ttl: 120, env_var: user_env_var)
    {
      '_plugin' => 'env_var',
      'var' => env_var,
      '_cache' => { 'ttl' => ttl }
    }
  end

  around(:each) do |example|
    with_project('cache_test', inventory: inventory) do |project|
      @project = project

      ENV[user_env_var] = 'player_one'
      ENV[tmpdir_env_var] = '/tmp'
      FileUtils.mkdir_p(File.join(project_path, 'plans'))
      File.write(File.join(project_path, 'plans', 'init.pp'), plan)

      example.run
    end
  end

  context 'setting cache' do
    let(:inventory) do
      { 'targets' => [
        { 'uri' => 'node1',
          'config' => {
            'ssh' => {
              'user' => plugin,
              'password' => plugin(ttl: 20)
            }
          } }
      ] }
    end

    it 'sets a unique ID based on the plugin hash minus the _cache' do
      run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      # This should set a unique ID for each different `env_var`, but not
      # different `cache` values
      expect(JSON.parse(File.read(project.cache_file)).keys)
        .to eq(%w[xihev-zaper-kerel-hyl])
    end

    context 'with plugins with different parameters' do
      let(:inventory) do
        { 'targets' => [
          { 'uri' => 'node1',
            'config' => {
              'ssh' => {
                'user' => plugin,
                'password' => plugin(ttl: 20),
                'tmpdir' => plugin(env_var: tmpdir_env_var)
              }
            } }
        ] }
      end

      it 'sets a unique ID based on the plugin hash minus the _cache' do
        run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
        expect(JSON.parse(File.read(project.cache_file)).keys)
          .to eq(%w[xihev-zaper-kerel-hyl xekin-reryb-tacuf-dis])
      end
    end
  end

  context 'refreshing cache' do
    let(:inventory) do
      { 'targets' => [
        { 'uri' => 'node1',
          'config' => {
            'ssh' => {
              'user' => plugin
            }
          } }
      ] }
    end

    it 'removes the existing cache file with --clear-cache' do
      run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      expect(JSON.parse(File.read(project.cache_file)).values.first)
        .to include({ 'result' => 'player_one' })

      ENV[user_env_var] = 'player_two'

      result = run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath} --clear-cache])
      expect(JSON.parse(result)).to eq('player_two')
    end

    it 'caches results' do
      run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      expect(JSON.parse(File.read(project.cache_file)).values.first)
        .to include({ 'result' => 'player_one' })

      ENV[user_env_var] = 'player_two'

      result = run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
      expect(JSON.parse(result)).to eq('player_one')
    end

    context 'with a short ttl' do
      let(:inventory) do
        { 'targets' => [
          { 'uri' => 'node1',
            'config' => {
              'ssh' => {
                'user' => plugin(ttl: 0)
              }
            } }
        ] }
      end

      it 'removes cache entries once the ttl has expired' do
        run_cli(%W[plan run cache_test --project #{project_path} -m #{mpath}])
        expect(JSON.parse(File.read(project.cache_file)).values.first)
          .to include({ 'result' => 'player_one' })
        ENV[user_env_var] = 'player_two'
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
