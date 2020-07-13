# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "errors gracefully attempting to apply a manifest block" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--targets #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:tflags) { %w[--no-host-key-check] }

    it 'prints a helpful error if Puppet is not present' do
      uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
      run_cli_json(%W[command run #{uninstall} --run-as root --sudo-password #{password}] + config_flags)

      result = run_cli_json(%w[plan run basic::class] + config_flags)
      error = result['details']['result_set'][0]['value']['_error']
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg']).to eq("Puppet is not installed on the target, please install it to enable 'apply'")
    end

    it 'raises a helpful error when a non-Puppet error is raised' do
      with_tempfile_containing('site', 'load_error()', '.pp') do |tempfile|
        run_cli(%W[apply #{tempfile.path} --run-as root --sudo-password #{password}] + config_flags)
        logs = @log_output.readlines
        expect(logs).to include(/`require': cannot load such file -- fake \(LoadError\)/)
        expect(logs).to include(/Something's gone terribly wrong! STDERR is logged/)
      end
    end

    context 'when it cannot connect to the target' do
      let(:password) { 'incorrect_password' }
      it 'displays a connection error' do
        result = run_cli_json(%w[plan run basic::class] + config_flags)
        error = result['details']['result_set'][0]['value']['_error']
        expect(error['kind']).to eq('puppetlabs.tasks/connect-error')
      end
    end
  end

  describe 'over winrm', winrm: true do
    let(:uri) { conn_uri('winrm') }
    let(:password) { conn_info('winrm')[:password] }
    let(:tflags) { %w[--no-ssl --no-ssl-verify] }

    it 'prints a helpful error if Puppet is not present' do
      result = run_cli_json(%w[plan run basic::class] + config_flags)
      error = result['details']['result_set'][0]['value']['_error']
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet was not found on the target or in $env:ProgramFiles, please install it to enable 'apply'")
        .or eq("Found a Ruby without Puppet present, please install Puppet or " \
               "remove Ruby from $env:Path to enable 'apply'")
    end
  end
end
