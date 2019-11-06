# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'

describe "CLI parses input" do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:script_path) { File.join(__dir__, '../fixtures/scripts/success.sh') }
  let(:config_flags) {
    %W[--format json
       --modulepath #{modulepath}
       --no-host-key-check ]
  }
  let(:target) { conn_uri('ssh', include_password: true) }

  it 'parses plan parameters' do
    params = ['string=foo',
              'string_bool="true"',
              '--targets', 'foo', '--targets', 'bar',
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

    expect(result).to eq(
      "name" => "parsing",
      "module_dir" => File.absolute_path(File.join(__dir__, '..', 'fixtures', 'modules', 'parsing')),
      "parameters" => {
        "string" => { "type" => "String" },
        "string_bool" => { "type" => "Variant[String, Boolean]" },
        "nodes" => { "type" => "TargetSpec" },
        "array" => { "type" => "Optional[Array]", "default_value" => nil },
        "hash" => { "type" => "Optional[Hash]", "default_value" => nil }
      }
    )
  end

  it 'fails with invalid plan params' do
    params = ['string=foo',
              'string_bool="true"',
              '--targets', 'foo', '--targets', 'bar',
              'array=13',
              'hash={"this": "that"}']
    result = run_cli_json(%w[plan run parsing] + params + config_flags, rescue_exec: true)
    expect(result["msg"]).to eq("parsing: parameter 'array' expects a value of type Undef or Array, got String")
  end

  it 'parses plan parameters' do
    params = ['string=false',
              'string_bool=true',
              '--targets', 'foo,bar',
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
    result = run_one_node(['task', 'run', 'parsing', '--targets', target] + params + config_flags)
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
    result = run_cli_json(['task', 'run', 'parsing', '--targets', target] + params + config_flags, rescue_exec: true)
    expect(result['_error']['msg']).to eq("Task parsing:\n parameter 'array' expects an Array value, got String")
  end

  it 'parses script parameters without munging task parameters', ssh: true do
    params = ['dont=split']
    result = run_one_node(['script', 'run', script_path, '--targets', target] + params + config_flags)
    expect(result['stdout']).to match(/dont=split/)
  end
end
