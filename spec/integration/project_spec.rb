# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/integration'

describe "When loading content", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Integration

  let(:local) { Bolt::Project.create_project(File.join(__dir__, '../fixtures/projects/local'), 'local') }
  let(:target) { conn_uri('ssh') }
  let(:config_flags) { %W[--no-host-key-check --password #{conn_info('ssh')[:password]}] }

  it "loads plans from project level content" do
    result = run_cli_json(%W[plan run local -t #{target} --boltdir #{local.path}] + config_flags)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "project level content can reference other modules" do
    result = run_cli_json(%W[task run local -t #{target}] + config_flags, project: local)
    expect(result["items"][0]["value"]["_output"].strip).to eq('polo')
  end

  it "runs plans namespaced with local project type" do
    result = run_cli_json(%W[plan run local -t #{target}] + config_flags, project: local)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "runs plans namespaced with embedded project type" do
    embedded = Bolt::Project.create_project(File.join(__dir__, '../fixtures/projects/embedded/Boltdir'), 'embedded')
    result = run_cli_json(%W[plan run embedded -t #{target}] + config_flags, project: embedded)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end

  it "runs plans namespaced to configured project name" do
    named = Bolt::Project.create_project(File.join(__dir__, '../fixtures/projects/named'), 'local')
    result = run_cli_json(%W[plan run test_project -t #{target}] + config_flags, project: named)
    expect(result[0]['value']['stdout'].strip).to eq('polo')
  end
end
