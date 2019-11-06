# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/puppet_agent'

describe "When a plan succeeds" do
  include BoltSpec::Integration
  include BoltSpec::Config
  include BoltSpec::Conn
  include BoltSpec::PuppetAgent

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
    result = run_cli(['plan', 'run', 'sample::single_task', '--targets', target] + config_flags,
                     outputter: Bolt::Outputter::JSON)
    json = JSON.parse(result)[0]
    expect(json['node']).to eq(target.to_s)
    expect(json['status']).to eq('success')
  end

  it 'prints a placeholder if no result is returned', ssh: true do
    result = run_cli(['plan', 'run', 'sample::single_task', '--targets', target] + config_flags,
                     outputter: Bolt::Outputter::Human)
    expect(result).to match(/got passed the message: hi there/)
    expect(result).to match(/Successful on 1 node:/)
    expect(result).to match(/Ran on 1 node/)
  end

  it 'runs a yaml plan', ssh: true do
    result = run_cli(['plan', 'run', 'sample::yaml', '--targets', target] + config_flags)
    expect(JSON.parse(result)).to eq('stdout' => "hello world\n", 'stderr' => '', 'exit_code' => 0)
  end

  context 'with puppet-agent installed for get_resources' do
    before(:all) do
      install(conn_uri('ssh', include_password: true))
    end

    after(:all) do
      # Remove .resource_types generated in boltdir
      FileUtils.rm_rf(fixture_path('configs', '.resource_types'))
      uninstall(conn_uri('ssh', include_password: true))
    end

    it 'runs registers types defined in $Boltdir/.resource_types', ssh: true do
      # generate types based and save in boltdir (based on value of --configfile)
      run_cli(%w[puppetfile generate-types] + config_flags)
      result = run_cli(['plan', 'run', 'resource_types', '--targets', target] + config_flags)
      expect(JSON.parse(result)).to eq('built-in' => 'success', 'core' => 'success', 'custom' => 'success')
    end
  end
end
