# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "when running over the local transport", bash: true do
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:uri) { 'localhost,local://foo' }
  let(:user) { ENV['USER'] }

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
end
