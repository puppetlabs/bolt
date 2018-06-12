# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'

describe "Passes the _task metaparameter" do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:config_flags) {
    %W[--format json
       --modulepath #{modulepath}
       --no-host-key-check ]
  }
  let(:uri) { conn_uri('ssh') }
  let(:password) { conn_info('ssh')[:password] }
  let(:target) { conn_uri('ssh', include_password: true) }

  it 'prints the _task metaparameter in a task' do
    params = ['--nodes', uri, '--password', password]
    result = run_cli_json(%w[task run task_param] + params + config_flags)
    expect(result['items'][0]['result']['_output']).to eq("Running task task_param\n")
  end
end
