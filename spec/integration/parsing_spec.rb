# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'

describe "CLI parses input" do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:config_flags) {
    %W[--format json
       --modulepath #{modulepath}
       --no-host-key-check ]
  }
  let(:target) { conn_uri('ssh', include_password: true) }

  it 'parses plan parameters' do
    params = ['string=foo',
              'string_bool="true"',
              '--nodes', 'foo', '--nodes', 'bar',
              'array=[1, 2, 3]',
              'hash={"this": "that"}']
    result = run_cli_json(%w[plan run parsing] + params + config_flags)
    expect(result).to eq("string" => "foo",
                         "string_bool" => "true",
                         "nodes" => %w[foo bar],
                         "array" => [1, 2, 3],
                         "hash" => { "this" => "that" })
  end

  it 'fails with invalid plan params' do
    params = ['string=foo',
              'string_bool="true"',
              '--nodes', 'foo', '--nodes', 'bar',
              'array=13',
              'hash={"this": "that"}']
    result = run_cli_json(%w[plan run parsing] + params + config_flags, rescue_exec: true)
    expect(result["msg"]).to eq("parsing: parameter 'array' expects a value of type Undef or Array, got Integer")
  end

  it 'parses task parameters', ssh: true do
    params = [
      'string_bool="true"',
      'array=[1, 2, 3]'
    ]
    result = run_one_node(['task', 'run', 'parsing', '--nodes', target] + params + config_flags)
    expect(result).to eq("string_bool" => "true",
                         "array" => [1, 2, 3])
  end

  it 'validates task parameters', ssh: true do
    params = [
      'string_bool="true"',
      'array="123"'
    ]
    result = run_cli_json(['task', 'run', 'parsing', '--nodes', target] + params + config_flags, rescue_exec: true)
    expect(result['_error']['msg']).to eq("Task parsing:\n parameter 'array' expects an Array value, got String")
  end
end
