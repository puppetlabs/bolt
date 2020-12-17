# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'using module based plugins' do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:inventory)     { {} }
  let(:plugin_config) { {} }
  let(:plugin_hooks)  { {} }
  let(:project_name)  { 'module_test' }
  let(:command)       { %W[plan run #{project_name} --project #{@project.path}] }
  let(:config) do
    { 'modulepath' => [fixtures_path('plugin_modules')],
      'plugins' => plugin_config,
      'plugin-hooks' => plugin_hooks }
  end

  let(:plan) do
    <<~PLAN
      plan #{project_name}() {
        return(get_target('node1').password)
      }
    PLAN
  end

  before :each do
    # Don't print error messages to the console
    allow($stdout).to receive(:puts)
  end

  around(:each) do |example|
    with_project(project_name, inventory: inventory, config: config) do |project|
      @project = project
      FileUtils.mkdir_p(project.plans_path)
      File.write(File.join(project.plans_path, 'init.pp'), plan)

      example.run
    end
  end

  context 'when resolving references' do
    let(:plugin) {
      {
        '_plugin' => 'identity',
        'value' => "ssshhh"
      }
    }

    let(:inventory) {
      { 'targets' => [
        { 'uri' => 'node1',
          'config' => {
            'ssh' => {
              'user' => 'me',
              'password' => plugin
            }
          } }
      ] }
    }

    it 'supports a config lookup' do
      output = run_cli(command)
      expect(output.strip).to eq('"ssshhh"')
    end

    it 'logs task output at trace level' do
      run_cli(command)
      output = @log_output.readlines
      expect(output).to include(/TRACE.*"value":{"value":"ssshhh"/)
    end

    context 'with bad parameters' do
      let(:plugin) {
        {
          '_plugin' => 'identity',
          'value' => 'something',
          'unexpected' => 'foo'
        }
      }

      it 'errors when the parameters dont match' do
        result = run_cli_json(command, rescue_exec: true)

        expect(result).to include('kind' => "bolt/validation-error")
        expect(result['msg']).to match(/Task identity::resolve_reference:\s*has no param/)
      end
    end

    context 'with a bad result' do
      let(:plugin) {
        {
          '_plugin' => 'bad_result',
          'not_value' => 'secret'
        }
      }

      it 'errors when the result is unexpected' do
        result = run_cli_json(command, rescue_exec: true)

        expect(result).to include('kind' => "bolt/plugin-error")
        expect(result['msg']).to match(/did not include a value/)
      end
    end

    context 'when a task fails' do
      let(:plugin) {
        {
          '_plugin' => 'error_plugin'
        }
      }

      it 'errors when the task fails' do
        result = run_cli_json(command, rescue_exec: true)

        expect(result).to include('kind' => "bolt/plugin-error")
        expect(result['msg']).to match(/The task failed/)
      end
    end
  end

  context 'when a plugin requires config' do
    let(:plugin) {
      {
        '_plugin' => 'conf_plug',
        'value' => "ssshhh"
      }
    }

    let(:inventory) {
      { 'targets' => [
        { 'uri' => 'node1',
          'config' => {
            'transport' => 'remote',
            'remote' => {
              'data' => plugin
            }
          } }
      ] }
    }

    let(:plan) do
      <<~PLAN
        plan #{project_name}() {
          return(get_target('node1').config)
        }
      PLAN
    end

    it 'fails when config key is present in bolt_plugin.json' do
      result = run_cli_json(command, rescue_exec: true)

      expect(result).to include('kind' => "bolt/invalid-plugin-data")
      expect(result['msg']).to match(/Found unsupported key 'config'/)
    end

    context 'with values specified in both bolt-project.yaml and inventory.yaml' do
      let(:project_path) { @project.path.to_s }

      context 'and merging config' do
        let(:plugin) { { '_plugin' => 'task_conf_plug', 'optional_key' => 'keep' } }
        let(:plugin_config) { { 'task_conf_plug' => { 'required_key' => 'foo', 'optional_key' => 'clobber' } } }

        it 'merges parameters set in config and does not pass _config' do
          result = run_cli_json(command)

          expect(result['remote']['data']).not_to include('_config' => plugin_config['conf_plug'])
          expect(result['remote']['data']).to include('_boltdir' => project_path)
          expect(result['remote']['data']).to include('required_key' => 'foo')
          expect(result['remote']['data']).to include('optional_key' => 'keep')
        end
      end

      context 'and using task metadata alone for config validation for expected success' do
        let(:plugin) { { '_plugin' => 'task_conf_plug', 'required_key' => 'foo' } }
        let(:plugin_config) { { 'task_conf_plug' => { 'optional_key' => 'bar' } } }

        it 'treats all required values from task paramter metadata as optional' do
          result = run_cli_json(command)

          expect(result['remote']['data']).not_to include('_config' => plugin_config['conf_plug'])
          expect(result['remote']['data']).to include('_boltdir' => project_path)
          expect(result['remote']['data']).to include('required_key' => 'foo')
          expect(result['remote']['data']).to include('optional_key' => 'bar')
        end
      end

      context 'and using task metadata alone for config validation for expected failure' do
        let(:plugin) { { '_plugin' => 'task_conf_plug' } }
        let(:plugin_config) { { 'task_conf_plug' => { 'random_key' => 'bar' } } }

        it 'forbids config entries that do not match task metadata schema' do
          expect { run_cli(command) }
            .to raise_error(Bolt::ValidationError, /task_conf_plug plugin contains unexpected key random_key/)
        end
      end
    end

    context 'with multiple task schemas to validate against' do
      context 'with valid type String string set in config and overriden in inventory' do
        let(:project_path) { @project.path.to_s }
        let(:plugin) {
          {
            '_plugin' => 'task_conf_plug',
            'required_key' => "foo",
            'intersection_key' => 1
          }
        }
        let(:plugin_config) { { 'task_conf_plug' => { 'intersection_key' => 'String' } } }

        it 'allows valid type in bolt-project.yaml and expected value is overriden in inventory' do
          result = run_cli_json(command)
          expect(result['remote']['data']).to include('_boltdir' => project_path)
          expect(result['remote']['data']).to include('required_key' => 'foo')
          expect(result['remote']['data']).to include('intersection_key' => 1)
        end
      end
    end
  end

  context 'when handling secrets' do
    let(:config_flags) { %W[--project #{@project.path}] }

    it 'calls the encrypt task' do
      result = run_cli(%w[secret encrypt secret_msg --plugin my_secret] + config_flags,
                       outputter: Bolt::Outputter::Human)
      # This is kind of brittle and we look for plaintext_value because this is really the identity task
      expect(result).to match(/"plaintext_value"=>"secret_msg"/)
    end

    it 'calls the decrypt task' do
      result = run_cli(%w[secret decrypt secret_msg --plugin my_secret] + config_flags,
                       outputter: Bolt::Outputter::Human)
      # This is kind of brittle and we look for "encrypted_value because this is really the identity task
      expect(result).to match(/"encrypted_value"=>"secret_msg"/)
    end
  end

  context 'when managing puppet_library', docker: true do
    let(:inventory) { docker_inventory(root: true) }
    let(:plan) do
      <<~PLAN
        plan #{project_name}() {
          apply_prep('ubuntu_node')
        }
      PLAN
    end

    context 'with an unsupported hook' do
      let(:plugin_hooks) do
        {
          'puppet_library' => {
            'plugin' => 'identity'
          }
        }
      end

      it 'fails cleanly' do
        result = run_cli_json(command, rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /Plugin identity does not support puppet_library/
        )
      end
    end

    context 'with an unknown plugin' do
      let(:plugin_hooks) do
        {
          'puppet_library' => {
            'plugin' => 'does_not_exist'
          }
        }
      end

      it 'fails cleanly' do
        result = run_cli_json(command, rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(/Unknown plugin:/)
      end
    end

    context 'with a failing plugin' do
      let(:plugin_hooks) {
        {
          'puppet_library' => {
            'plugin' => 'error_plugin'
          }
        }
      }

      it 'fails cleanly' do
        result = run_cli_json(command, rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /The task failed with exit code 1/
        )
      end
    end
  end
end
