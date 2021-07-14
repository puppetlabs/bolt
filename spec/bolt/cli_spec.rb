# frozen_string_literal: true

require 'spec_helper'

require 'bolt/cli'

require 'bolt_spec/env_var'
require 'bolt_spec/files'
require 'bolt_spec/project'

describe Bolt::CLI do
  include BoltSpec::EnvVar
  include BoltSpec::Files
  include BoltSpec::Project

  before(:each) do
    # Disable printing to the console.
    allow($stdout).to receive(:puts)
    allow($stderr).to receive(:puts)

    # Don't allow the logger to be configured, it'll leak doubles all over the
    # place.
    allow(Bolt::Logger).to receive(:configure)

    # Disable analytics screen view. It doesn't like doubles. :(
    allow_any_instance_of(described_class).to receive(:submit_screen_view)

    # Stub all the things.
    allow(Bolt::Analytics).to receive(:build_client).and_return(analytics)
    allow(Bolt::Application).to receive(:new).and_return(application)
    allow(Bolt::Config).to receive(:from_project).and_return(config)
    allow(Bolt::Executor).to receive(:new).and_return(executor)
    allow(Bolt::Inventory).to receive(:from_config).and_return(inventory)
    allow(Bolt::Outputter).to receive(:for_format).and_return(outputter)
    allow(Bolt::PAL).to receive(:new).and_return(pal)
    allow(Bolt::Plugin).to receive(:setup).and_return(plugin)
    allow(Bolt::Project).to receive(:create_project).and_return(project)
    allow(Bolt::Rerun).to receive(:new).and_return(rerun)

    # Allow the stubbed outputter to yield from its spinner.
    allow(outputter).to receive(:spin) { |&block| block.call }
  end

  # Allow doubles to receive all messages. Messages to doubles will return the
  # double.
  # https://relishapp.com/rspec/rspec-mocks/docs/basics/null-object-doubles
  let(:analytics)   { double('analytics').as_null_object }
  let(:application) { double('application').as_null_object }
  let(:config)      { double('config').as_null_object }
  let(:executor)    { double('executor').as_null_object }
  let(:inventory)   { double('inventory').as_null_object }
  let(:outputter)   { double('outputter').as_null_object }
  let(:pal)         { double('pal').as_null_object }
  let(:plugin)      { double('plugin').as_null_object }
  let(:project)     { double('project').as_null_object }
  let(:rerun)       { double('rerun').as_null_object }

  describe '#parse' do
    context 'arguments' do
      it 'parses commands and options' do
        options = Bolt::CLI.new(%w[script run script.sh foo bar --targets localhost]).parse
        expect(options).to include(
          subcommand: 'script',
          action:     'run',
          object:     'script.sh',
          leftovers:  %w[foo bar],
          targets:    ['localhost']
        )
      end

      it 'errors with an unknown command' do
        expect {
          Bolt::CLI.new(%w[explode]).parse
        }.to raise_error(Bolt::CLIError, /'explode' is not a Bolt command/)
      end

      it 'errors with an unknown action' do
        expect {
          Bolt::CLI.new(%w[command show]).parse
        }.to raise_error(Bolt::CLIError, /Expected action 'show' to be one of/)
      end

      it 'errors without a required action' do
        expect {
          Bolt::CLI.new(%w[command]).parse
        }.to raise_error(Bolt::CLIError, /Expected an action/)
      end
    end

    context 'help' do
      it 'shows help text with no arguments' do
        expect {
          expect {
            Bolt::CLI.new([]).parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/Usage.*bolt/m).to_stdout
      end

      it 'shows help text with `help`' do
        expect {
          expect {
            Bolt::CLI.new(%w[help]).parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/Usage.*bolt/m).to_stdout
      end

      it 'shows help text with `help <command>`' do
        expect {
          expect {
            Bolt::CLI.new(%w[help command]).parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/Usage.*bolt command <action>/m).to_stdout
      end

      it 'shows help text with `help <command> <action>`' do
        expect {
          expect {
            Bolt::CLI.new(%w[help command run]).parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/Usage.*bolt command run/m).to_stdout
      end

      it 'shows help text with `--help`' do
        expect {
          expect {
            Bolt::CLI.new(%w[--help]).parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/Usage.*bolt/m).to_stdout
      end
    end

    context 'version' do
      it 'shows Bolt version' do
        expect {
          expect {
            Bolt::CLI.new(%w[--version]).parse
          }.to raise_error(Bolt::CLIExit)
        }.to output(/#{Bolt::VERSION}/).to_stdout
      end
    end

    context 'apply' do
      it 'errors with both a manifest file and --execute' do
        expect {
          Bolt::CLI.new(%w[apply file.pp --execute notice('example') --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /--execute is unsupported when specifying a manifest file/
        )
      end

      it 'errors with neither a manifest file or --execute' do
        expect {
          Bolt::CLI.new(%w[apply --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /a manifest file or --execute is required/
        )
      end
    end

    context 'command run' do
      let(:command) { 'whoami' }

      it 'reads a command from stdin' do
        expect($stdin).to receive(:read).and_return(command)
        options = Bolt::CLI.new(%w[command run - --targets localhost]).parse
        expect(options[:object]).to eq(command)
      end

      it 'reads a command from a file' do
        with_tempfile_containing('command', command) do |file|
          options = Bolt::CLI.new(%W[command run @#{file.path} --targets localhost]).parse
          expect(options[:object]).to eq(command)
        end
      end

      it 'errors without a command' do
        expect {
          Bolt::CLI.new(%w[command run --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a command to run/
        )
      end

      it 'errors with an empty command' do
        expect {
          Bolt::CLI.new(['command', 'run', '', '--targets', 'localhost']).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a command to run/
        )
      end
    end

    context 'file download' do
      it 'errors without a source' do
        expect {
          Bolt::CLI.new(%w[file download --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a source/
        )
      end

      it 'errors without a destination' do
        expect {
          Bolt::CLI.new(%w[file download source --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a destination/
        )
      end
    end

    context 'file upload' do
      it 'errors without a source' do
        expect {
          Bolt::CLI.new(%w[file upload --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a source/
        )
      end

      it 'errors without a destination' do
        expect {
          Bolt::CLI.new(%w[file upload source --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a destination/
        )
      end
    end

    describe 'lookup' do
      it 'errors without a key' do
        expect {
          Bolt::CLI.new(%w[lookup --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a key to look up/
        )
      end

      it 'errors with both a targeting option and --plan-hierarchy' do
        expect {
          Bolt::CLI.new(%w[lookup key --targets localhost --plan-hierarchy]).parse
        }.to raise_error(
          Bolt::CLIError,
          /The 'lookup' command accepts either targeting option OR --plan-hierarchy/
        )
      end

      it 'errors without a targeting option or --plan-hierarchy' do
        expect {
          Bolt::CLI.new(%w[lookup key]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Command requires a targeting option/
        )
      end
    end

    describe 'module add' do
      it 'errors without a module name' do
        expect {
          Bolt::CLI.new(%w[module add]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a module name/
        )
      end
    end

    describe 'plan convert' do
      it 'errors without a plan' do
        expect {
          Bolt::CLI.new(%w[plan convert]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a plan/
        )
      end
    end

    describe 'plan new' do
      it 'errors without a plan' do
        expect {
          Bolt::CLI.new(%w[plan new]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a plan name/
        )
      end
    end

    describe 'plan run' do
      it 'parses parameters' do
        options = Bolt::CLI.new(%w[plan run bolt foo=bar]).parse
        expect(options).to include(
          params: { 'foo' => 'bar' }
        )
      end

      it 'errors without a plan' do
        expect {
          Bolt::CLI.new(%w[plan run]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a plan to run/
        )
      end

      it 'errors with --params and param=value pairs' do
        expect {
          Bolt::CLI.new(%w[plan run bolt --params {"foo":"bar"} baz=bak]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Parameters must be specified through either the --params option or param=value pairs/
        )
      end
    end

    describe 'script run' do
      it 'accepts multiple extra arguments' do
        options = Bolt::CLI.new(%w[script run script.sh foo bar baz --targets localhost]).parse
        expect(options).to include(
          leftovers: %w[foo bar baz]
        )
      end
    end

    describe 'secret decrypt' do
      it 'errors without ciphertext' do
        expect {
          Bolt::CLI.new(%w[secret decrypt]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a value to decrypt/
        )
      end
    end

    describe 'secret encrypt' do
      it 'errors without plaintext' do
        expect {
          Bolt::CLI.new(%w[secret encrypt]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a value to encrypt/
        )
      end
    end

    describe 'task run' do
      it 'parses parameters' do
        options = Bolt::CLI.new(%w[task run bolt foo=bar --targets localhost]).parse
        expect(options).to include(
          params: { 'foo' => 'bar' }
        )
      end

      it 'errors without a task' do
        expect {
          Bolt::CLI.new(%w[task run --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Must specify a task to run/
        )
      end

      it 'errors with --params and param=value pairs' do
        expect {
          Bolt::CLI.new(%w[task run bolt --params {"foo":"bar"} baz=bak --targets localhost]).parse
        }.to raise_error(
          Bolt::CLIError,
          /Parameters must be specified through either the --params option or param=value pairs/
        )
      end
    end
  end

  describe '#execute' do
    let(:cli) { described_class.new([]) }

    describe 'loading the project' do
      it 'loads from the current directory' do
        in_project do |project|
          expect(Bolt::Project).to receive(:find_boltdir).with(project.path.to_s)
          cli.execute({})
        end
      end

      it 'loads from BOLT_PROJECT environment variable' do
        with_project do |project|
          with_env_vars('BOLT_PROJECT' => project.path.to_s) do
            expect(Bolt::Project).to receive(:create_project).with(project.path.to_s, anything)
            cli.execute({})
          end
        end
      end

      context 'with --project' do
        it 'it loads from Boltdir' do
          with_project do |project|
            FileUtils.mkdir(project.path + 'Boltdir')
            expect(Bolt::Project).to receive(:create_project).with(project.path + 'Boltdir')
            cli.execute({ project: project.path })
          end
        end

        it 'loads from the directory' do
          with_project do |project|
            expect(Bolt::Project).to receive(:create_project).with(project.path)
            cli.execute({ project: project.path })
          end
        end
      end
    end

    describe 'checking for gem install' do
      it 'displays a warning when Bolt is installed as a gem' do
        with_env_vars('BOLT_GEM' => nil) do
          allow(cli).to receive(:incomplete_install?).and_return(true)
          expect(Bolt::Logger).to receive(:warn).with('gem_install', anything)
          cli.execute({})
        end
      end

      it 'does not display a warning when BOLT_GEM is set' do
        with_env_vars('BOLT_GEM' => 'true') do
          allow(cli).to receive(:incomplete_install?).and_return(true)
          cli.execute({})
          expect(Bolt::Logger).not_to receive(:warn).with('gem_install', anything)
        end
      end
    end

    describe 'analytics' do
      before(:each) do
        allow(cli).to receive(:submit_screen_view).and_call_original
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'submits a screen view' do
        allow(analytics).to receive(:screen_view) do |screen, fields|
          expect(screen).to eq('command_run')
          expect(fields).to include(
            output_format:     anything,
            boltdir_type:      anything,
            puppet_plan_count: anything,
            yaml_plan_count:   anything
          )
        end

        cli.execute({ subcommand: 'command', action: 'run' })
      end

      it 'submits a screen view with inventory information' do
        allow(analytics).to receive(:screen_view) do |screen, fields|
          expect(screen).to eq('task_run')
          expect(fields).to include(
            target_nodes:      anything,
            inventory_nodes:   anything,
            inventory_groups:  anything,
            inventory_version: anything
          )
        end

        cli.execute({ subcommand: 'task', action: 'run', targets: [] })
      end

      it 'counts Puppet language and YAML plans in the project' do
        with_project do |project|
          FileUtils.mkdir_p(project.path + 'plans')
          FileUtils.touch(project.path + 'plans' + 'puppet.pp')
          FileUtils.touch(project.path + 'plans' + 'yaml.yaml')

          allow(config).to receive(:project).and_return(project)
          allow(File).to receive(:exist?).and_call_original

          allow(analytics).to receive(:screen_view) do |_screen, fields|
            expect(fields).to include(
              puppet_plan_count: 1,
              yaml_plan_count:   1
            )
          end

          cli.execute({})
        end
      end

      it 'completes analytics submission' do
        expect(analytics).to receive(:finish)
        cli.execute({})
      end
    end

    describe 'CLI overrides' do
      let(:options) { { transport: 'ssh' } }

      it 'warns with an inventory file' do
        cli.execute(options)
        expect(@log_output.readlines).to include(
          /WARN .* CLI arguments \["transport"\] might be overridden by Inventory/
        )
      end

      it 'warns when BOLT_INVENTORY is set' do
        with_env_vars('BOLT_INVENTORY' => '{"targets":["foo"]}') do
          cli.execute(options)
          expect(@log_output.readlines).to include(
            /WARN .* CLI arguments \["transport"\] might be overridden by Inventory: BOLT_INVENTORY/
          )
        end
      end

      it 'does not warn with no inventory' do
        allow(config).to receive(:inventoryfile).and_return(nil)
        allow(config).to receive(:default_inventoryfile).and_return(nil)
        allow(File).to receive(:exist?).and_return(false)

        cli.execute(options)
        expect(@log_output.readlines).not_to include(
          /WARN .* CLI arguments \["transport"\] might be overridden by Inventory/
        )
      end
    end

    describe 'query' do
      let(:options)    { { subcommand: 'command', action: 'run', object: 'whoami', query: query } }
      let(:pdb_client) { double('pdb_client').as_null_object }
      let(:query)      { 'nodes{}' }

      it 'resolves targets based on the query' do
        allow(plugin).to receive(:puppetdb_client).and_return(pdb_client)
        expect(pdb_client).to receive(:query_certnames).with(query)
        cli.execute(options)
      end
    end

    describe 'bundled content' do
      before(:each) do
        allow(pal).to receive(:list_plans).and_return([%w[plan description]])
        allow(pal).to receive(:list_tasks).and_return([%w[task description]])
      end

      it 'calculates bundled content for a plan' do
        expect(analytics).to receive(:bundled_content=) do |content|
          expect(content['Plan']).not_to be_empty
          expect(content['Task']).not_to be_empty
        end

        cli.execute(subcommand: 'plan', action: 'run', object: 'plan')
      end

      it 'calculates bundled content for a task' do
        expect(analytics).to receive(:bundled_content=) do |content|
          expect(content['Plan']).not_to be_empty
          expect(content['Task']).not_to be_empty
        end

        cli.execute(subcommand: 'task', action: 'run', object: 'task')
      end

      it 'does not calculate bundled content for other commands' do
        expect(analytics).to receive(:bundled_content=) do |content|
          expect(content['Plan']).to be_empty
          expect(content['Task']).to be_empty
        end

        cli.execute(subcommand: 'command', action: 'run', object: 'command')
      end
    end
  end

  describe '#process_command' do
    let(:cli)    { described_class.new([]) }
    let(:result) { double('result', to_hash: {}).as_null_object }

    context 'apply' do
      before(:each) do
        expect(application).to receive(:apply).and_return(result)
      end

      let(:options) { { subcommand: 'apply' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update).with(result)
        cli.execute(options)
      end

      it 'prints a summary of the results' do
        expect(outputter).to receive(:print_apply_result).with(result)
        cli.execute(options)
      end
    end

    context 'command run' do
      before(:each) do
        expect(application).to receive(:command_run).and_return(result)
      end

      let(:options) { { subcommand: 'command', action: 'run', object: 'whoami' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update).with(result)
        cli.execute(options)
      end

      it 'prints a summary of the results' do
        expect(outputter).to receive(:print_summary).with(result, anything)
        cli.execute(options)
      end
    end

    context 'file download' do
      before(:each) do
        expect(application).to receive(:file_download).and_return(result)
      end

      let(:options) { { subcommand: 'file', action: 'download', object: '/tmp', leftovers: ['/tmp'] } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update).with(result)
        cli.execute(options)
      end

      it 'prints a summary of the results' do
        expect(outputter).to receive(:print_summary).with(result, anything)
        cli.execute(options)
      end
    end

    context 'file upload' do
      before(:each) do
        expect(application).to receive(:file_upload).and_return(result)
      end

      let(:options) { { subcommand: 'file', action: 'upload', object: '/tmp', leftovers: ['/tmp'] } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update).with(result)
        cli.execute(options)
      end

      it 'prints a summary of the results' do
        expect(outputter).to receive(:print_summary).with(result, anything)
        cli.execute(options)
      end
    end

    context 'group show' do
      before(:each) do
        expect(application).to receive(:group_show).and_return({})
      end

      let(:options) { { subcommand: 'group', action: 'show' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the groups' do
        expect(outputter).to receive(:print_groups)
        cli.execute(options)
      end
    end

    describe 'guide' do
      before(:each) do
        expect(application).to receive(:guide).and_return({})
      end

      let(:options) { { subcommand: 'guide' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end
    end

    describe 'inventory show' do
      before(:each) do
        expect(application).to receive(:inventory_show).and_return(result)
      end

      let(:options) { { subcommand: 'inventory', action: 'show' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the target list' do
        expect(outputter).to receive(:print_targets)
        cli.execute(options)
      end
    end

    describe 'inventory show --detail' do
      before(:each) do
        expect(application).to receive(:inventory_show).and_return(result)
      end

      let(:options) { { subcommand: 'inventory', action: 'show', detail: true } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the target data' do
        expect(outputter).to receive(:print_target_info)
        cli.execute(options)
      end
    end

    context 'lookup' do
      before(:each) do
        expect(application).to receive(:lookup).and_return(result)
      end

      let(:options) { { subcommand: 'lookup' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update)
        cli.execute(options)
      end

      it 'prints the results' do
        expect(outputter).to receive(:print_result_set).with(result)
        cli.execute(options)
      end
    end

    context 'lookup --plan-hierarchy' do
      before(:each) do
        expect(application).to receive(:plan_lookup).and_return(result)
      end

      let(:options) { { subcommand: 'lookup', plan_hierarchy: true } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the result' do
        expect(outputter).to receive(:print_plan_lookup).with(result)
        cli.execute(options)
      end
    end

    context 'module add' do
      before(:each) do
        expect(application).to receive(:module_add)
      end

      let(:options) { { subcommand: 'module', action: 'add', object: 'puppetlabs/stdlib' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(application).to receive(:module_add).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end
    end

    context 'module generate-types' do
      before(:each) do
        expect(application).to receive(:module_generate_types)
      end

      let(:options) { { subcommand: 'module', action: 'generate-types' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end
    end

    context 'module install' do
      before(:each) do
        expect(application).to receive(:module_install)
      end

      let(:options) { { subcommand: 'module', action: 'install' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(application).to receive(:module_install).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end
    end

    context 'module show' do
      before(:each) do
        expect(application).to receive(:module_show).and_return(result)
      end

      let(:options) { { subcommand: 'module', action: 'show' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the modules' do
        expect(outputter).to receive(:print_module_list).with(result)
        cli.execute(options)
      end
    end

    context 'plan convert' do
      before(:each) do
        expect(application).to receive(:plan_convert)
      end

      let(:options) { { subcommand: 'plan', action: 'convert' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end
    end

    context 'plan new' do
      before(:each) do
        expect(application).to receive(:plan_new).and_return({})
      end

      let(:options) { { subcommand: 'plan', action: 'new' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the plan information' do
        expect(outputter).to receive(:print_new_plan)
        cli.execute(options)
      end
    end

    context 'plan run' do
      before(:each) do
        expect(application).to receive(:plan_run).and_return(result)
      end

      let(:options) { { subcommand: 'plan', action: 'run', object: 'plan' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'prints the results' do
        expect(outputter).to receive(:print_plan_result).with(result)
        cli.execute(options)
      end
    end

    context 'plan show' do
      before(:each) do
        allow(application).to receive(:list_plans).and_return({})
      end

      let(:options) { { subcommand: 'plan', action: 'show' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the plan list' do
        expect(outputter).to receive(:print_plans)
        cli.execute(options)
      end
    end

    context 'plan show plan' do
      before(:each) do
        expect(application).to receive(:show_plan).and_return({})
      end

      let(:options) { { subcommand: 'plan', action: 'show', object: 'plan' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the plan information' do
        expect(outputter).to receive(:print_plan_info)
        cli.execute(options)
      end
    end

    context 'plugin show' do
      before(:each) do
        expect(application).to receive(:plugin_show).and_return({})
      end

      let(:options) { { subcommand: 'plugin', action: 'show' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the plan information' do
        expect(outputter).to receive(:print_plugin_list)
        cli.execute(options)
      end
    end

    context 'project init' do
      before(:each) do
        expect(application).to receive(:project_init)
      end

      let(:options) { { subcommand: 'project', action: 'init' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end
    end

    context 'project migrate' do
      before(:each) do
        expect(application).to receive(:project_migrate)
      end

      let(:options) { { subcommand: 'project', action: 'migrate' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end
    end

    context 'script run' do
      before(:each) do
        expect(application).to receive(:script_run).and_return(result)
      end

      let(:options) { { subcommand: 'script', action: 'run', object: 'script.sh' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update).with(result)
        cli.execute(options)
      end

      it 'prints a summary of the results' do
        expect(outputter).to receive(:print_summary).with(result, anything)
        cli.execute(options)
      end
    end

    context 'secret createkeys' do
      before(:each) do
        expect(application).to receive(:secret_createkeys).and_return(result)
      end

      let(:options) { { subcommand: 'secret', action: 'createkeys' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the result' do
        expect(outputter).to receive(:print_message).with(result)
        cli.execute(options)
      end
    end

    context 'secret decrypt' do
      before(:each) do
        expect(application).to receive(:secret_decrypt).and_return(result)
      end

      let(:options) { { subcommand: 'secret', action: 'decrypt' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the result' do
        expect(outputter).to receive(:print_message).with(result)
        cli.execute(options)
      end
    end

    context 'secret encrypt' do
      before(:each) do
        expect(application).to receive(:secret_encrypt).and_return(result)
      end

      let(:options) { { subcommand: 'secret', action: 'encrypt' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the result' do
        expect(outputter).to receive(:print_message).with(result)
        cli.execute(options)
      end
    end

    context 'task run' do
      before(:each) do
        expect(application).to receive(:task_run).and_return(result)
      end

      let(:options) { { subcommand: 'task', action: 'run', object: 'task' } }

      it 'returns SUCCESS with a successful result' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'returns FAILURE with a failing result' do
        allow(result).to receive(:ok?).and_return(false)
        expect(cli.execute(options)).to eq(Bolt::CLI::FAILURE)
      end

      it 'updates the rerun file' do
        expect(rerun).to receive(:update).with(result)
        cli.execute(options)
      end

      it 'prints the results' do
        expect(outputter).to receive(:print_summary).with(result, anything)
        cli.execute(options)
      end
    end

    context 'task show' do
      before(:each) do
        expect(application).to receive(:list_tasks).and_return({})
      end

      let(:options) { { subcommand: 'task', action: 'show' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the task list' do
        expect(outputter).to receive(:print_tasks)
        cli.execute(options)
      end
    end

    context 'task show task' do
      before(:each) do
        expect(application).to receive(:show_task).and_return({})
      end

      let(:options) { { subcommand: 'task', action: 'show', object: 'task' } }

      it 'returns SUCCESS' do
        expect(cli.execute(options)).to eq(Bolt::CLI::SUCCESS)
      end

      it 'prints the task information' do
        expect(outputter).to receive(:print_task_info)
        cli.execute(options)
      end
    end
  end
end
