# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/catalog'

describe "errors gracefully attempting to apply a manifest block" do
  include BoltSpec::Conn
  include BoltSpec::Integration

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:config_flags) { %W[--format json --nodes #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:tflags) { %w[--no-host-key-check] }

    it 'prints a helpful error if Puppet is not present' do
      result = run_cli_json(%w[plan run basic::class] + config_flags)
      error = result[0]['result']['_error']
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg']).to eq("Puppet is not installed on the target, please install it to enable 'apply'")
    end
  end

  describe 'over winrm', winrm: true do
    let(:uri) { conn_uri('winrm') }
    let(:password) { conn_info('winrm')[:password] }
    let(:tflags) { %w[--no-ssl --no-ssl-verify] }

    it 'prints a helpful error if Puppet is not present' do
      result = run_cli_json(%w[plan run basic::class] + config_flags)
      error = result[0]['result']['_error']
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet is not installed on the target in $env:ProgramFiles, please install it to enable 'apply'")
        .or eq("Found a Ruby without Puppet present, please install Puppet or " \
               "remove Ruby from $env:Path to enable 'apply'")
    end
  end
end
