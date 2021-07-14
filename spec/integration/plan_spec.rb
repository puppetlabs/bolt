# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'plans' do
  include BoltSpec::Conn
  include BoltSpec::Integration
  include BoltSpec::Files
  include BoltSpec::Project

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:config_flags) {
    ['--format', 'json',
     '--project', fixtures_path('configs', 'empty'),
     '--modulepath', modulepath,
     '--no-host-key-check']
  }
  let(:modulepath)      { fixtures_path('modules') }
  let(:target)          { conn_uri('ssh', include_password: true) }
  let(:project_config)  { { 'modules' => [] } }

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
      expect(json['value']).to eq(
        "stdout"        => "I am a yaml plan\n",
        "stderr"        => "",
        "merged_output" => "I am a yaml plan\n",
        "exit_code"     => 0
      )
    end

    context "using the human outputter" do
      around(:each) do |example|
        with_project(config: { 'modulepath' => [modulepath] }) do |project|
          @project = project
          example.run
        end
      end

      let(:config_flags) { ['--no-host-key-check'] }
      let(:opts)         { { outputter: Bolt::Outputter::Human, project: @project } }
      let(:project)      { @project }

      context 'output' do
        context 'out::message' do
          it 'outputs messages' do
            result = run_cli(%w[plan run output], outputter: Bolt::Outputter::Human, project: project)
            expect(result).to match(/Outputting a message/)
          end

          it 'logs messages at the info level' do
            run_cli(%w[plan run output], outputter: Bolt::Outputter::Human, project: project)
            expect(@log_output.readlines).to include(/INFO.*Outputting a message/)
          end
        end

        context 'out::verbose' do
          it 'outputs verbose messages in verbose mode' do
            result = run_cli(%w[plan run output::verbose --verbose], outputter: Bolt::Outputter::Human,
                                                                     project: project)
            expect(result).to match(/Hi, I'm Dave/)
          end

          it 'does not output verbose messages' do
            result = run_cli(%w[plan run output::verbose], outputter: Bolt::Outputter::Human, project: project)
            expect(result).not_to match(/Hi, I'm Dave/)
          end

          it 'logs verbose messages at the debug level' do
            run_cli(%w[plan run output::verbose], outputter: Bolt::Outputter::Human, project: project)
            expect(@log_output.readlines).to include(/DEBUG.*Hi, I'm Dave/)
          end
        end
      end

      it "prints the spinner when running executor functions", ssh: true do
        expect_any_instance_of(Bolt::Outputter::Human).to receive(:start_spin).at_least(:once)
        run_cli(%w[plan run sample::noop --targets #{target}] + config_flags, **opts)
      end

      it "doesn't print the spinner when running non-executor functions", ssh: true do
        expect_any_instance_of(Bolt::Outputter::Human).not_to receive(:start_spin)
        run_cli(%w[plan run output] + config_flags, **opts)
      end

      it 'prints formatted Puppet errors' do
        output = run_cli(%w[plan run output::error] + config_flags, **opts)
        expect(output).to match(Regexp.escape("Error({'msg' => 'Something went horribly, horribly wrong'})"))
      end
    end

    context 'using the logger outputter' do
      it 'logs messages' do
        with_project do |project|
          run_cli_json(%W[plan run logs -m #{modulepath}], project: project)
          expect(@log_output.readlines).to include(
            /TRACE.*This is a trace message/,
            /DEBUG.*This is a debug message/,
            /WARN.*This is a warn message/,
            /INFO.*This is an info message/,
            /ERROR.*This is an error message/,
            /FATAL.*This is a fatal message/
          )
        end
      end
    end

    it 'runs a yaml plan', ssh: true do
      result = run_cli(['plan', 'run', 'sample::yaml', '--targets', target] + config_flags)
      expect(JSON.parse(result)).to eq(
        'stdout'        => "hello world\n",
        'stderr'        => '',
        'merged_output' => "hello world\n",
        'exit_code'     => 0
      )
    end

    context 'with puppet-agent installed for get_resources' do
      let(:config_flags) { %W[--project #{@project.path} -m #{modulepath}] }

      around(:each) do |example|
        with_project(config: project_config, inventory: docker_inventory(root: true)) do |project|
          @project = project
          example.run
        end
      end

      context 'with module subcommand' do
        let(:project_config) { { 'modules' => [] } }

        it 'runs registers types defined in $project/.resource_types', ssh: true do
          run_cli(%w[module generate-types] + config_flags)
          result = run_cli_json(%w[plan run resource_types -t nix_agents] + config_flags)
          expect(result).to eq('built-in' => 'success', 'core' => 'success', 'custom' => 'success')
        end
      end

      it 'caches plan info when generating types', ssh: true do
        fact_info = {
          "facts" => {
            "description" => /A plan that retrieves facts and stores/,
            "module" => /.*/,
            "name" => "facts",
            "parameters" => {
              "targets" => {
                "description" => "List of targets to retrieve the facts for.",
                "sensitive" => false,
                "type" => "TargetSpec"
              }
            }
          }
        }

        with_project(config: project_config) do |project|
          config_flags = %W[-m #{modulepath} --project #{project.path} --no-host-key-check]
          expect(Dir.children(project.path)).not_to include('.plan_cache.json')

          run_cli(%w[module generate-types] + config_flags)
          expect(Dir.children(project.path)).to include('.plan_cache.json')
          cache = JSON.parse(File.read(project.plan_cache_file))
          expect(cache).to include(fact_info)
        end
      end
    end
  end

  context 'when a plan errors' do
    it 'provides the location where a Puppet error was raised' do
      result = run_cli_json(%w[plan run error::inner] + config_flags)

      expect(result['details']).to match(
        'file'   => /inner.pp/,
        'line'   => 3,
        'column' => 3
      )
    end

    it 'provides the location from a nested plan where a Puppet error was raised' do
      result = run_cli_json(%w[plan run error::outer] + config_flags)

      expect(result['details']).to match(
        'file'   => /inner.pp/,
        'line'   => 3,
        'column' => 3
      )
    end

    it 'provides errors for Puppet preformatted errors with line numbers' do
      result = run_cli_json(%W[plan run error::no_task -t #{target}] + config_flags)

      expect(result['details']).to include(
        'file' => /no_task.pp/,
        'line' => 4,
        'column' => 3
      )
    end

    it 'provides the location where a Bolt error was raised', ssh: true do
      result = run_cli_json(%W[plan run error::run_fail -t #{target}] + config_flags)

      expect(result['details']['result_set'][0]['value']['_error']['details']).to include(
        'file' => /run_fail.pp/,
        'line' => 4
      )
    end

    it 'provides the location from a nest plan where a Bolt error was raised', ssh: true do
      result = run_cli_json(%W[plan run error::call_run_fail -t #{target}] + config_flags)

      expect(result['details']).to include(
        'file' => /run_fail.pp/,
        'line' => 4
      )
    end
  end
end
