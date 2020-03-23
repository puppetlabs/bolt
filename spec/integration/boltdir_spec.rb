# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/integration'

describe "When loading content", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Integration

  let(:boltdir) { File.join(__dir__, '../fixtures/project_dir') }
  let(:config_flags) { %W[--boltdir #{boltdir} --no-host-key-check --password #{conn_info('ssh')[:password]}] }
  let(:target) { conn_uri('ssh') }

  it "loads plans from project level content" do
    result = run_cli_json(%W[plan run test_project -t #{target}] + config_flags)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "project level content can reference other modules" do
    result = run_cli_json(%W[task run test_project -t #{target}] + config_flags)
    expect(result["items"][0]["value"]["_output"].strip).to eq('polo')
  end
end
