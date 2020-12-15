# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "when running over the docker transport", docker: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:whoami)      { "whoami" }
  let(:modulepath)  { fixtures_path('modules') }
  let(:stdin_task)  { "sample::stdin" }
  let(:uri)         { (1..2).map { |i| "#{conn_uri('docker')}?id=#{i}" }.join(',') }
  let(:user)        { 'root' }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  context 'when using CLI options' do
    let(:config_flags) {
      %W[--targets #{uri} --no-host-key-check --format json --modulepath #{modulepath}]
    }

    it 'runs multiple commands' do
      result = run_nodes(%W[command run #{whoami}] + config_flags)
      expect(result.map { |r| r['stdout'].strip }).to eq([user, user])
    end

    it 'reports errors when command fails' do
      result = run_failed_nodes(%w[command run boop] + config_flags)
      expect(result[0]['_error']).to be
    end

    it 'runs multiple tasks', :reset_puppet_settings do
      result = run_nodes(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(result.map { |r| r['message'].strip }).to eq(%w[somemessage somemessage])
    end

    it 'reports errors when task fails', :reset_puppet_settings do
      result = run_failed_nodes(%w[task run results fail=true] + config_flags)
      expect(result[0]['_error']).to be
    end
  end

  context 'when using a project' do
    let(:config) do
      { 'format' => 'json',
        'modulepath' => modulepath }
    end
    let(:default_inv) do
      { 'config' => {
        'transport' => 'docker',
        'docker' => {
          'user' => user
        }
      } }
    end
    let(:inv)                 { default_inv }
    let(:project)             { @project }
    let(:config_flags)        { %W[--targets #{uri} --project #{project.path}] }
    let(:single_target_conf)  { %W[--targets #{conn_uri('docker')} --project #{project.path}] }
    let(:interpreter_task)    { 'sample::interpreter' }
    let(:interpreter_ext) do
      { 'config' => {
        'docker' => {
          'interpreters' => {
            '.py' => '/usr/bin/python3'
          }
        }
      } }
    end
    let(:interpreter_no_ext) do
      { 'config' => {
        'docker' => {
          'interpreters' => {
            '.py' => '/usr/bin/python3'
          }
        }
      } }
    end

    around :each do |example|
      with_project(config: config, inventory: inv) do |project|
        @project = project
        example.run
      end
    end

    context 'with interpreters without dots configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_no_ext) }

      it 'runs task with specified interpreter key py', :reset_puppet_settings do
        result = run_nodes(%W[task run #{interpreter_task} message=short] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    context 'with interpreters without dots configured' do
      let(:inv) { Bolt::Util.deep_merge(default_inv, interpreter_ext) }

      it 'runs task with interpreter key .py', :reset_puppet_settings do
        result = run_nodes(%W[task run #{interpreter_task} message=short
                              --project #{project.path}] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[short short])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[short short])
      end
    end

    it 'task fails when bad shebang is not overriden', :reset_puppet_settings do
      result = run_failed_node(%W[task run #{interpreter_task} message=short] + single_target_conf)
      expect(result['_error']['msg']).to be
    end
  end
end
