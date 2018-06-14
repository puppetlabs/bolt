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

  it 'shows a plan with aliased type' do
    result = run_cli_json(%w[plan show parsing] + config_flags)
    target_spec_type = "TargetSpec = Boltlib::TargetSpec = Variant[String[1], Object[{name => 'Target', attributes =>"\
    " {'uri' => String[1], 'options' => {type => Hash[String[1], Data], value => {}}}, functions => {'host' => "\
    "Callable[[0, 0], String[1]], 'name' => Callable[[0, 0], String[1]], 'password' => Callable[[0, 0], "\
    "Optional[String[1]]], 'port' => Callable[[0, 0], Optional[Integer]], 'protocol' => Callable[[0, 0], "\
    "Optional[String[1]]], 'user' => Callable[[0, 0], Optional[String[1]]]}}], Array[Boltlib::TargetSpec]]"

    expect(result).to eq(
      "name" => "parsing",
      "parameters" => {
        "string" => { "type" => "String" },
        "string_bool" => { "type" => "Variant[String, Boolean]" },
        "nodes" => { "type" => target_spec_type },
        "array" => { "type" => "Optional[Array]", "default_value" => nil },
        "hash" => { "type" => "Optional[Hash]", "default_value" => nil }
      }
    )
  end

  it 'fails with invalid plan params' do
    params = ['string=foo',
              'string_bool="true"',
              '--nodes', 'foo', '--nodes', 'bar',
              'array=13',
              'hash={"this": "that"}']
    result = run_cli_json(%w[plan run parsing] + params + config_flags, rescue_exec: true)
    expect(result["msg"]).to eq("parsing: parameter 'array' expects a value of type Undef or Array, got String")
  end

  it 'parses plan parameters' do
    params = ['string=false',
              'string_bool=true',
              '--nodes', 'foo,bar',
              'array=[13]',
              'hash={"this": "that"}']
    result = run_cli_json(%w[plan run parsing] + params + config_flags, rescue_exec: true)
    expect(result).to eq(
      'array' => [13],
      'hash' => { 'this' => 'that' },
      'nodes' => %w[foo bar],
      'string' => 'false',
      'string_bool' => true
    )
  end

  it 'parses task parameters', ssh: true do
    params = [
      'string_bool="true"',
      'array=[1, 2, 3]'
    ]
    result = run_one_node(['task', 'run', 'parsing', '--nodes', target] + params + config_flags)
    expect(result).to eq("string_bool" => "true",
                         "array" => [1, 2, 3],
                         "_task" => "parsing")
  end

  it 'validates task parameters', ssh: true do
    params = [
      'string_bool="true"',
      'array="123"',
      '_task="parsing"'
    ]
    result = run_cli_json(['task', 'run', 'parsing', '--nodes', target] + params + config_flags, rescue_exec: true)
    expect(result['_error']['msg']).to eq("Task parsing:\n parameter 'array' expects an Array value, got String")
  end
end
