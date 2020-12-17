# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "when sending an out::message event" do
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { fixtures_path('modules') }
  let(:config_flags) { %W[--modulepath #{modulepath}] }

  it "prints to stdout when format is human" do
    output = run_cli(%w[plan run output] + config_flags, outputter: Bolt::Outputter::Human)
    expect(output).to include("Outputting a message")
  end

  it "prints to stderr when format is json" do
    expect {
      run_cli(%w[plan run output --format json] + config_flags)
    }.to output("Outputting a message\n").to_stderr
  end
end
