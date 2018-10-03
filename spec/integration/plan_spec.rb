# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "When a plan succeeds" do
  include BoltSpec::Integration
  include BoltSpec::Config
  include BoltSpec::Conn

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:modulepath) { fixture_path('modules') }
  let(:config_flags) {
    ['--format', 'json',
     '--configfile', fixture_path('configs', 'empty.yml'),
     '--modulepath', modulepath,
     '--no-host-key-check']
  }
  let(:target) { conn_uri('ssh', include_password: true) }

  it 'prints the result', ssh: true do
    result = run_cli(%w[plan run sample] + config_flags, outputter: Bolt::Outputter::Human)
    expect(result.strip).to eq('Plan completed successfully with no result')
  end

  it 'prints a placeholder if no result is returned', ssh: true do
    result = run_cli(['plan', 'run', 'sample::single_task', '--nodes', target] + config_flags,
                     outputter: Bolt::Outputter::JSON)
    json = JSON.parse(result)[0]
    expect(json['node']).to eq(target.to_s)
    expect(json['status']).to eq('success')
  end

  it 'prints a placeholder if no result is returned', ssh: true do
    result = run_cli(['plan', 'run', 'sample::single_task', '--nodes', target] + config_flags,
                     outputter: Bolt::Outputter::Human)
    expect(result).to match(/got passed the message: hi there/)
    expect(result).to match(/Successful on 1 node:/)
    expect(result).to match(/Ran on 1 node/)
  end
end
