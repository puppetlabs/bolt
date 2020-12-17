# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "Passes the _task metaparameter" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath)    { fixtures_path('modules') }
  let(:config_flags)  { %W[--format json --targets #{target} --modulepath #{modulepath}] }

  describe 'over ssh', ssh: true do
    let(:target) { conn_uri('ssh', include_password: true) }

    it 'prints the _task metaparameter in a task' do
      result = run_cli_json(%w[task run task_param --no-host-key-check] + config_flags)
      expect(result['items'][0]['value']['_output']).to eq("Running task task_param\n")
    end
  end

  describe 'over winrm', winrm: true do
    let(:target) { conn_uri('winrm', include_password: true) }

    it 'prints the _task metaparameter in a task' do
      result = run_cli_json(%w[task run task_param::win --no-ssl] + config_flags)
      expect(result['items'][0]['value']['_output']).to eq("Running task task_param::win\r\n")
    end
  end
end
