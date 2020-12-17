# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "resource instance in plans", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { fixtures_path('modules') }
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
