# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "when running over the lxd transport", lxd: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:uri) { (1..2).map { |i| "#{conn_uri('lxd')}?id=#{i}" }.join(',') }
  let(:user) { 'root' }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  context 'when using CLI options' do
    let(:config_flags) {
      %W[--nodes #{uri} --no-host-key-check --format json --modulepath #{modulepath}]
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

  context 'when using a configfile' do
    let(:config) do
      { 'format' => 'json',
        'modulepath' => modulepath,
        'transport' => 'lxd',
        'lxd' => {
          'user' => user
        } }
    end

    let(:config_flags) { %W[--nodes #{uri}] }
    let(:single_target_conf) { %W[--nodes #{conn_uri('lxd')}] }
    let(:interpreter_task) { 'sample::interpreter' }
    let(:interpreter_ext) do
      { 'interpreters' => {
        '.py' => '/usr/bin/python3'
      } }
    end
    let(:interpreter_no_ext) do
      { 'interpreters' => {
        'py' => '/usr/bin/python3'
      } }
    end

    it 'runs task with specified interpreter key py', :reset_puppet_settings do
      lxd_conf = { 'lxd' => config['lxd'].merge(interpreter_no_ext) }
      with_tempfile_containing('conf', YAML.dump(config.merge(lxd_conf))) do |conf|
        result =
          run_nodes(%W[task run #{interpreter_task} message=somemessage
                       --configfile #{conf.path}] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[somemessage somemessage])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[somemessage somemessage])
      end
    end

    it 'runs task with interpreter key .py', :reset_puppet_settings do
      lxd_conf = { 'lxd' => config['lxd'].merge(interpreter_ext) }
      with_tempfile_containing('conf', YAML.dump(config.merge(lxd_conf))) do |conf|
        result = run_nodes(%W[task run #{interpreter_task} message=somemessage
                              --configfile #{conf.path}] + config_flags)
        expect(result.map { |r| r['env'].strip }).to eq(%w[somemessage somemessage])
        expect(result.map { |r| r['stdin'].strip }).to eq(%w[somemessage somemessage])
      end
    end

    it 'task fails when bad shebang is not overriden', :reset_puppet_settings do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_failed_node(%W[task run #{interpreter_task} message=somemessage
                                    --configfile #{conf.path}] + single_target_conf)
        expect(result['_error']['msg']).to be
      end
    end
  end
end
