# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe "CLI parses input" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:modulepath) { fixtures_path('modules') }
  let(:script_path) { fixtures_path('scripts', 'success.sh') }
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
      "description" => nil,
      "module_dir" => fixtures_path('modules', 'parsing'),
      "parameters" => {
        "string" => { "type" => "String", "sensitive" => false },
        "string_bool" => { "type" => "Variant[String, Boolean]", "sensitive" => false },
        "nodes" => { "type" => "TargetSpec", "sensitive" => false },
        "array" => { "type" => "Optional[Array]", "default_value" => 'undef', "sensitive" => false },
        "hash" => { "type" => "Optional[Hash]", "default_value" => 'undef', "sensitive" => false }
      },
      "private" => false
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

  it 'warns when metadata is invalid' do
    params = ['string="catdog"']
    run_cli(['task', 'run', 'sample::invalid', '--targets', target] + params + config_flags)
    logs = @log_output.readlines
    expect(logs).to include(/WARN.*Metadata for task 'sample::invalid' contains unknown keys: anything/)
  end

  it 'parses script parameters without munging task parameters', ssh: true do
    params = ['dont=split']
    result = run_one_node(['script', 'run', script_path, '--targets', target] + params + config_flags)
    expect(result['stdout']).to match(/dont=split/)
  end

  it 'parses environment variables', ssh: true do
    script = fixtures_path('modules', 'env_var', 'tasks', 'get_var.sh')
    output = run_cli_json(%W[script run #{script} -t #{target} --env-var test_var=123] + config_flags)
    expect(output['items'][0]['value']['stdout'].strip).to eq('123')
  end
end
