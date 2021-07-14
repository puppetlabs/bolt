# frozen_string_literal: true

require 'spec_helper'

require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'commands' do
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:base_config) { { 'modulepath' => modulepath } }
  let(:config)      { base_config }
  let(:inventory)   { {} }
  let(:modulepath)  { fixtures_path('modules') }
  let(:outputter)   { Bolt::Outputter::Human }
  let(:project)     { @project }

  around(:each) do |example|
    with_project(config: config, inventory: inventory) do |project|
      @project = project
      example.run
    end
  end

  describe 'inventory show' do
    let(:inventoryfile) { fixtures_path('inventory', 'invalid.yaml') }

    it 'errors if the specified inventoryfile is invalid' do
      expect {
        run_cli_json(%W[inventory show --inventoryfile #{inventoryfile}], project: project)
      }.to raise_error(
        Bolt::Error,
        /Could not parse/
      )
    end
  end

  describe 'plan run' do
    it 'formats the results of a passing task' do
      result = run_cli_json(%w[plan run sample::successful_task], project: project)

      expect(result.first).to include(
        'target' => 'localhost',
        'status' => 'success',
        'action' => 'task',
        'object' => 'sample::success',
        'value'  => { '_output' => /success/ }
      )
    end

    it 'formats the results of a failing task' do
      result = run_cli_json(%w[plan run sample::failing_task], project: project)

      expect(result.first).to include(
        'target' => 'localhost',
        'status' => 'failure',
        'action' => 'task',
        'object' => 'sample::error',
        'value'  => {
          '_error' => {
            'issue_code' => 'TASK_ERROR',
            'msg'        => anything,
            'kind'       => 'puppetlabs.tasks/task-error',
            'details'    => anything
          },
          '_output' => /error/
        }
      )
    end

    it 'errors for non-existent plans' do
      result = run_cli_json(%w[plan run abcdefg], project: project)

      expect(result['kind']).to eq('bolt/unknown-plan')
      expect(result['msg']).to match(/Could not find a plan named 'abcdefg'/)
    end

    context 'with invalid plans' do
      let(:modulepath) { fixtures_path('invalid_mods') }

      it 'errors' do
        result = run_cli_json(%w[plan run sample::single_task], project: project)

        expect(result['kind']).to eq('bolt/pal-error')
        expect(result['msg']).to match(/Syntax error at/)
      end
    end
  end

  describe 'plan show' do
    it 'shows available plans with descriptions' do
      result = run_cli_json(%w[plan show], project: project)
      expect(result['plans']).to include(
        ['sample', anything],
        ['sample::single_task', anything],
        ['sample::three_tasks', anything],
        ['sample::two_tasks', anything],
        ['sample::yaml', anything]
      )
    end

    it 'shows the modulepath' do
      result = run_cli_json(%w[plan show], project: project)
      expect(result['modulepath']).to include(modulepath)
    end

    it 'shows individual plan data' do
      result = run_cli_json(%w[plan show sample::optional_params_task], project: project)
      expect(result).to include(
        "name" => "sample::optional_params_task",
        "description" => "Demonstrates plans with optional parameters",
        "module_dir" => fixtures_path('modules', 'sample'),
        "parameters" => {
          "param_mandatory" => {
            "type" => "String",
            "description" => "A mandatory parameter",
            "sensitive" => false
          },
          "param_optional" => {
            "type" => "Optional[String]",
            "description" => "An optional parameter",
            "sensitive" => false
          },
          "param_with_default_value" => {
            "type" => "String",
            "description" => "A parameter with a default value",
            "default_value" => "'foo'",
            "sensitive" => false
          }
        }
      )
    end

    it 'shows individual YAML plan data' do
      result = run_cli_json(%w[plan show sample::yaml], project: project)
      expect(result).to include(
        "name" => "sample::yaml",
        "description" => nil,
        "module_dir" => fixtures_path('modules', 'sample'),
        "parameters" => {
          "nodes" => {
            "type" => "TargetSpec",
            "sensitive" => false
          },
          "param_optional" => {
            "type" => "Optional[String]",
            "default_value" => 'undef',
            "sensitive" => false
          },
          "param_with_default_value" => {
            "type" => "String",
            "default_value" => 'hello',
            "sensitive" => false
          }
        }
      )
    end

    it 'errors when the plan is not in the modulepath' do
      expect { run_cli_json(%w[plan show abcdefg], project: project) }.to raise_error(
        Bolt::Error,
        /Could not find a plan named 'abcdefg'/
      )
    end

    context 'with plans configured' do
      let(:config) do
        base_config.merge('plans' => ['sample::single_task'])
      end

      it 'only shows allowed plans' do
        result = run_cli_json(%w[plan show], project: project)
        expect(result['plans']).to eq(
          [['sample::single_task', 'one line plan to show we can run a task by name']]
        )
      end
    end

    context 'with invalid yard doc parameters' do
      it 'warns that docs do not match plan signature' do
        result = run_cli_json(%w[plan show sample::documented_param_typo], project: project)

        expect(result).to include(
          "name" => 'sample::documented_param_typo',
          "module_dir" => fixtures_path('modules', 'sample'),
          "description" => nil,
          "parameters" => {
            "oops" => {
              "type" => "String",
              "default_value" => "typo",
              "sensitive" => false
            }
          }
        )

        expect(@log_output.readlines).to include(
          /parameter 'not_oops' does not exist.*sample::documented_param_typo/m
        )
      end
    end

    context 'with invalid plans' do
      let(:modulepath) { fixtures_path('invalid_mods') }

      it 'warns but still shows other valid plans' do
        result = run_cli_json(%w[plan show], project: project)

        expect(result['plans']).to include(
          ['sample::ok', anything]
        )

        expect(result['plans']).not_to include(
          ['sample::single_task', anything]
        )

        expect(@log_output.readlines).to include(/Syntax error at.*single_task.pp/m)
      end
    end
  end

  describe 'task run' do
    let(:flags) { %w[--targets localhost] }

    it 'errors for non-existent tasks' do
      expect {
        run_cli_json(%w[task run sample::dne] + flags, project: project)
      }.to raise_error(
        Bolt::Error,
        /Could not find a task named 'sample::dne'/
      )
    end

    it 'errors when unknown parameters are specified' do
      expect {
        run_cli_json(%w[task run sample::params foo=one bar=two] + flags, project: project)
      }.to raise_error(
        Bolt::PAL::PALError,
        %r{Task sample::params:\n(?x:
          )\s*has no parameter named 'foo'\n(?x:
          )\s*has no parameter named 'bar'}
      )
    end

    it 'errors when required parameters are not specified' do
      expect {
        run_cli_json(%w[task run sample::params mandatory_string=foo] + flags, project: project)
      }.to raise_error(
        Bolt::PAL::PALError,
        %r{Task sample::params:\n(?x:
          )\s*expects a value for parameter 'mandatory_integer'\n(?x:
          )\s*expects a value for parameter 'mandatory_boolean'}
      )
    end

    it 'errors when parameters do not match the expected data types' do
      params = {
        'mandatory_string' => 'str',
        'mandatory_integer' => 10,
        'mandatory_boolean' => 'str',
        'non_empty_string' => 'foo',
        'optional_string' => 10
      }.to_json

      expect {
        run_cli_json(%W[task run sample::params --params #{params}] + flags, project: project)
      }.to raise_error(
        Bolt::PAL::PALError,
        %r{Task sample::params:\n(?x:
          )\s*parameter 'mandatory_boolean' expects a Boolean value, got String\n(?x:
          )\s*parameter 'optional_string' expects a value of type Undef or String,(?x:
                                        ) got Integer}
      )
    end

    it 'errors when the parameter values are outside the expected ranges' do
      params = {
        'mandatory_string' => '0123456789a',
        'mandatory_integer' => 10,
        'mandatory_boolean' => true,
        'non_empty_string' => 'foo',
        'optional_integer' => 10
      }.to_json

      expect {
        run_cli_json(%W[task run sample::params --params #{params}] + flags, project: project)
      }.to raise_error(
        Bolt::PAL::PALError,
        %r{Task sample::params:\n(?x:
          )\s*parameter 'mandatory_string' expects a String\[1, 10\] value, got String\n(?x:
          )\s*parameter 'optional_integer' expects a value of type Undef or Integer\[-5, 5\],(?x:
                                         ) got Integer\[10, 10\]}
      )
    end

    context 'running in no-op mode' do
      before(:each) do
        flags.concat(['--noop'])
      end

      it 'errors on a task that does not support noop' do
        expect {
          run_cli_json(%w[task run sample::no_noop] + flags, project: project)
        }.to raise_error(
          Bolt::Error,
          /Task does not support noop/
        )
      end

      it 'errors on a task without metadata' do
        expect {
          run_cli_json(%w[task run sample::echo] + flags, project: project)
        }.to raise_error(
          Bolt::Error,
          /Task does not support noop/
        )
      end
    end
  end

  describe 'task show' do
    it 'shows available tasks with descriptions' do
      result = run_cli_json(%w[task show], project: project)
      expect(result['tasks']).to include(
        ['sample', nil],
        ['sample::echo', nil],
        ['sample::no_noop', 'Task with no noop'],
        ['sample::noop', 'Task with noop'],
        ['sample::notice', nil],
        ['sample::params', 'Task with parameters'],
        ['sample::ps_noop', 'Powershell task with noop'],
        ['sample::stdin', nil],
        ['sample::winstdin', nil]
      )
    end

    it 'shows the modulepath' do
      result = run_cli_json(%w[task show], project: project)
      expect(result['modulepath']).to include(modulepath)
    end

    it 'shows individual task data' do
      result = run_cli_json(%w[task show sample::params], project: project)
      expect(result).to include(
        "name" => "sample::params",
        "module_dir" => fixtures_path('modules', 'sample'),
        "metadata" => {
          "anything" => true,
          "description" => "Task with parameters",
          "extensions" => {},
          "input_method" => 'stdin',
          "parameters" => {
            "mandatory_string" => {
              "description" => "Mandatory string parameter",
              "type" => "String[1, 10]"
            },
            "mandatory_integer" => {
              "description" => "Mandatory integer parameter",
              "type" => "Integer"
            },
            "mandatory_boolean" => {
              "description" => "Mandatory boolean parameter",
              "type" => "Boolean"
            },
            "non_empty_string" => {
              "type" => "String[1]"
            },
            "optional_string" => {
              "description" => "Optional string parameter",
              "type" => "Optional[String]"
            },
            "optional_integer" => {
              "description" => "Optional integer parameter",
              "type" => "Optional[Integer[-5,5]]"
            },
            "no_type" => {
              "description" => "A parameter without a type"
            }
          },
          "supports_noop" => true
        }
      )
    end

    it 'errors when the task is not in the modulepath' do
      expect { run_cli_json(%w[task show abcdefg], project: project) }.to raise_error(
        Bolt::Error,
        /Could not find a task named 'abcdefg'/
      )
    end

    context 'with tasks configured' do
      let(:config) do
        base_config.merge('tasks' => ['sample::params'])
      end

      it 'only shows allowed tasks' do
        result = run_cli_json(%w[task show], project: project)
        expect(result['tasks']).to eq(
          [['sample::params', 'Task with parameters']]
        )
      end
    end

    context 'with invalid tasks' do
      let(:modulepath) { fixtures_path('invalid_mods') }

      it 'warns but still shows other valid tasks' do
        result = run_cli_json(%w[task show], project: project)

        expect(result['tasks']).to include(
          ['sample::ok', nil]
        )

        expect(result['tasks']).not_to include(
          ['sample::params', 'Task with parameters']
        )

        expect(@log_output.readlines).to include(/unexpected token/)
      end
    end
  end
end

describe "when loading bolt for CLI invocation" do
  context 'and calling help' do
    def cli_loaded_features
      cli_loader = File.join(__dir__, '..', 'fixtures', 'scripts', 'bolt_cli_loader.rb')
      `bundle exec ruby #{cli_loader}`.split("\n")
    end

    let(:loaded_features) { cli_loaded_features }

    [
      # ruby_smb + dependencies
      'ruby_smb',
      'bindata',
      'rubyntlm',
      'windows_error',
      # FFI + dependencies
      'ffi',
      # orchestrator client + dependencies
      'orchestrator_client',
      'faraday',
      'multipart-post',
      # httpclient + dependencies
      'httpclient',
      # locale + dependencies
      'locale',
      # minitar + dependencies
      'minitar',
      # addressable + dependencies
      'addressable',
      'public_suffix',
      # terminal-table + dependencies
      'terminal-table',
      'unicode-display_width',
      # net-ssh + dependencies
      'net-ssh'
    ].each do |gem_name|
      it "does not load #{gem_name} gem code" do
        gem_path = Regexp.escape(Gem.loaded_specs[gem_name].full_gem_path)
        any_gem_source_code = a_string_matching(gem_path)
        fail_msg = "loaded unexpected #{gem_name} gem code from #{gem_path}"
        expect(loaded_features).not_to include(any_gem_source_code), fail_msg
      end
    end

    [
      'openssl/x509.rb'
    ].each do |code_path|
      it "does not load #{code_path}" do
        specific_code = a_string_matching(Regexp.escape(code_path))
        fail_msg = "loaded unexpected #{code_path}"
        expect(loaded_features).not_to include(specific_code), fail_msg
      end
    end
  end
end
