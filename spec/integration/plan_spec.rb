# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/puppet_agent'

describe 'plans' do
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

  context "When a plan succeeds" do
    it 'prints the result', ssh: true do
      result = run_cli(%w[plan run sample] + config_flags, outputter: Bolt::Outputter::Human)
      expect(result.strip).to eq('Plan completed successfully with no result')
    end

    it 'prints a placeholder if no result is returned', ssh: true do
      result = run_cli(['plan', 'run', 'sample::single_task', '--targets', target] + config_flags,
                       outputter: Bolt::Outputter::JSON)
      json = JSON.parse(result)[0]
      expect(json['target']).to eq(target.to_s)
      expect(json['status']).to eq('success')
    end

    it 'prints a placeholder if no result is returned', ssh: true do
      result = run_cli(['plan', 'run', 'sample::single_task', '--targets', target] + config_flags,
                       outputter: Bolt::Outputter::Human)
      expect(result).to match(/got passed the message: hi there/)
      expect(result).to match(/Successful on 1 target:/)
      expect(result).to match(/Ran on 1 target/)
    end

    it 'runs a puppet plan from a subdir', ssh: true do
      result = run_cli(%W[plan run sample::subdir::command --targets #{target}] + config_flags)

      json = JSON.parse(result)[0]
      expect(json['value']['stdout']).to eq("From subdir\n")
    end

    it 'runs a yaml plan from a subdir of plans', ssh: true do
      result = run_cli(%W[plan run yaml::subdir::init --targets #{target}] + config_flags)

      json = JSON.parse(result)[0]
      expect(json['target']).to eq(target)
      expect(json['status']).to eq('success')
      expect(json['value']).to eq("stdout" => "I am a yaml plan\n", "stderr" => "", "exit_code" => 0)
    end

    it 'runs a yaml plan', ssh: true do
      result = run_cli(['plan', 'run', 'sample::yaml', '--targets', target] + config_flags)
      expect(JSON.parse(result)).to eq('stdout' => "hello world\n", 'stderr' => '', 'exit_code' => 0)
    end

    context 'with puppet-agent installed for get_resources' do
      around(:each) do |example|
        original = ENV['BOLT_MODULE_FEATURE']
        ENV['BOLT_MODULE_FEATURE'] = 'true'
        install(conn_uri('ssh', include_password: true))
        example.run
      ensure
        ENV['BOLT_MODULE_FEATURE'] = original
        FileUtils.rm_rf(fixture_path('configs', '.resource_types'))
        uninstall(conn_uri('ssh', include_password: true))
      end

      it 'runs registers types defined in $project/.resource_types', ssh: true do
        # generate types based and save in project (based on value of --configfile)
        run_cli(%w[puppetfile generate-types] + config_flags)
        result = run_cli(['plan', 'run', 'resource_types', '--targets', target] + config_flags)
        expect(JSON.parse(result)).to eq('built-in' => 'success', 'core' => 'success', 'custom' => 'success')
      end

      it 'runs registers types defined in $project/.resource_types', ssh: true do
        # generate types based and save in project (based on value of --configfile)
        run_cli(%w[module generate-types] + config_flags)
        result = run_cli(['plan', 'run', 'resource_types', '--targets', target] + config_flags)
        expect(JSON.parse(result)).to eq('built-in' => 'success', 'core' => 'success', 'custom' => 'success')
      end
    end
  end

  context 'when a plan errors' do
    it 'provides the location where the plan failed' do
      result = run_cli_json(%w[plan run error::inner] + config_flags)

      expect(result['details']).to match(
        'file'   => /inner.pp/,
        'line'   => 3,
        'column' => 3
      )
    end

    it 'provides the location where a nested plan failed' do
      result = run_cli_json(%w[plan run error::outer] + config_flags)

      expect(result['details']).to match(
        'file'   => /inner.pp/,
        'line'   => 3,
        'column' => 3
      )
    end
  end
end
