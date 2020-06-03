# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'

describe "resource instance in plans", ssh: true do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:config_flags) do
    %W[--format json --targets #{conn_uri('ssh')}] +
      %W[--password #{conn_info('ssh')[:password]}] +
      %W[--modulepath #{modulepath} --no-host-key-check]
  end

  it 'can add an event' do
    result = run_cli_json(%w[plan run resources::add_event] + config_flags)
    expect(result).not_to include('kind')
    expect(result['events']).to eq([{ "update" => { "time" => "warp" } }])
  end
end
