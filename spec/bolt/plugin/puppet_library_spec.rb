# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/plugin'
require 'bolt/analytics'
require 'bolt_spec/plans'

describe Bolt::Plugin::Module do
  include BoltSpec::Files
  # These tests to not actually use the plan mocking just the executor/inventory setup
  include BoltSpec::Plans

  let(:modulepath) { [fixtures_path('plugin_modules')] }
  let(:config_data) { { 'modulepath' => modulepath } }

  let(:library_hook) {
    { 'plugin' => 'puppet_agent',
      '_run_as' => 'me' }
  }

  let(:inventory_data) {
    { 'version' => 2,
      'targets' => [{
        'name' => 'example.com',
        'plugin_hooks' => { 'puppet_library' => library_hook }
      }] }
  }

  def capture_opts
    install_options = nil
    allow(executor).to receive(:run_task) do |targets, task, _arguments, options|
      val = case task.name
            when "puppet_agent::install"
              install_options = options
              {}
            when "puppet_agent::version"
              { "version" => nil }
            else
              {}
            end
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.new(target, value: val)
      end)
    end

    executor.transport_features = []
    result = run_plan('inv_plans::puppet_library', 'nodes' => 'example.com')
    expect(result.value).to eq(nil)
    install_options
  end

  context 'with _run_as in the module plugin' do
    it 'runs the correct command' do
      install_options = capture_opts
      expect(install_options).to include(run_as: 'me')
    end
  end

  context 'without _run_as in the module plugin' do
    let(:library_hook) {
      { 'plugin' => 'puppet_agent' }
    }

    it 'runs the correct command' do
      install_options = capture_opts
      expect(install_options).to_not include(run_as: 'me')
    end
  end

  context 'without _run_as in the task plugin' do
    let(:library_hook) {
      { 'plugin' => 'task',
        'task' => 'puppet_agent::install',
        '_run_as' => 'me' }
    }

    it 'runs the correct command' do
      install_options = capture_opts
      expect(install_options).to include(run_as: 'me')
    end
  end

  context 'without _run_as in the task plugin' do
    let(:library_hook) {
      { 'plugin' => 'task',
        'task' => 'puppet_agent::install' }
    }

    it 'runs the correct command' do
      install_options = capture_opts
      expect(install_options).to_not include(run_as: 'me')
    end
  end
end
