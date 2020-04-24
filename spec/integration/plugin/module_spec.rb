# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'using module based plugins' do
  include BoltSpec::Conn
  include BoltSpec::Integration

  def with_boltdir(config: nil, inventory: nil, plan: nil)
    Dir.mktmpdir do |tmpdir|
      File.write(File.join(tmpdir, 'bolt.yaml'), config.to_yaml) if config
      File.write(File.join(tmpdir, 'inventory.yaml'), inventory.to_yaml) if inventory
      if plan
        plan_dir = File.join(tmpdir, 'modules', 'test_plan', 'plans')
        FileUtils.mkdir_p(plan_dir)
        File.write(File.join(plan_dir, 'init.pp'), plan)
      end
      yield tmpdir
    end
  end

  let(:plugin_config) { {} }
  let(:plugin_hooks) { {} }

  let(:config) {
    { 'modulepath' => ['modules', File.join(__dir__, '../../fixtures/plugin_modules')],
      'plugins' => plugin_config,
      'plugin_hooks' => plugin_hooks }
  }

  let(:plan) do
    <<~PLAN
      plan test_plan() {
        return(get_target('node1').password)
      }
    PLAN
  end

  let(:inventory) { {} }

  around(:each) do |example|
    with_boltdir(inventory: inventory, config: config, plan: plan) do |project|
      @project = project
      example.run
    end
  end

  let(:project) { @project }

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
      output = run_cli(['plan', 'run', 'test_plan', '--boltdir', project])

      expect(output.strip).to eq('"ssshhh"')
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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

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
        plan test_plan() {
          return(get_target('node1').config)
        }
      PLAN
    end

    it 'fails when config key is present in bolt_plugin.json' do
      result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

      expect(result).to include('kind' => "bolt/invalid-plugin-data")
      expect(result['msg']).to match(/Found unsupported key 'config'/)
    end

    context 'with values specified in both bolt.yaml and inventory.yaml' do
      context 'and merging config' do
        let(:plugin) { { '_plugin' => 'task_conf_plug', 'optional_key' => 'keep' } }
        let(:plugin_config) { { 'task_conf_plug' => { 'required_key' => 'foo', 'optional_key' => 'clobber' } } }

        it 'merges parameters set in config and does not pass _config' do
          result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project])

          expect(result['remote']['data']).not_to include('_config' => plugin_config['conf_plug'])
          expect(result['remote']['data']).to include('_boltdir' => project)
          expect(result['remote']['data']).to include('required_key' => 'foo')
          expect(result['remote']['data']).to include('optional_key' => 'keep')
        end
      end

      context 'and using task metadata alone for config validation for expected success' do
        let(:plugin) { { '_plugin' => 'task_conf_plug', 'required_key' => 'foo' } }
        let(:plugin_config) { { 'task_conf_plug' => { 'optional_key' => 'bar' } } }

        it 'treats all required values from task paramter metadata as optional' do
          result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project])

          expect(result['remote']['data']).not_to include('_config' => plugin_config['conf_plug'])
          expect(result['remote']['data']).to include('_boltdir' => project)
          expect(result['remote']['data']).to include('required_key' => 'foo')
          expect(result['remote']['data']).to include('optional_key' => 'bar')
        end
      end

      context 'and using task metadata alone for config validation for expected failure' do
        let(:plugin) { { '_plugin' => 'task_conf_plug' } }
        let(:plugin_config) { { 'task_conf_plug' => { 'random_key' => 'bar' } } }

        it 'forbids config entries that do not match task metadata schema' do
          result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

          expect(result).to include('kind' => "bolt/validation-error")
          expect(result['msg']).to match(/Config for task_conf_plug plugin contains unexpected key random_key/)
        end
      end
    end

    context 'with multiple task schemas to validate against' do
      context 'with valid type String string set in config and overriden in inventory' do
        let(:plugin) {
          {
            '_plugin' => 'task_conf_plug',
            'required_key' => "foo",
            'intersection_key' => 1
          }
        }
        let(:plugin_config) { { 'task_conf_plug' => { 'intersection_key' => 'String' } } }

        it 'allows valid type in bolt.yaml and expected value is overriden in inventory' do
          result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project])
          expect(result['remote']['data']).to include('_boltdir' => project)
          expect(result['remote']['data']).to include('required_key' => 'foo')
          expect(result['remote']['data']).to include('intersection_key' => 1)
        end
      end
    end
  end

  context 'when handling secrets' do
    it 'calls the encrypt task' do
      result = run_cli(['secret', 'encrypt', 'secret_msg', '--plugin', 'my_secret', '--boltdir', project],
                       outputter: Bolt::Outputter::Human)
      # This is kind of brittle and we look for plaintext_value because this is really the identity task
      expect(result).to match(/"plaintext_value"=>"secret_msg"/)
    end

    it 'calls the decrypt task' do
      result = run_cli(['secret', 'decrypt', 'secret_msg', '--plugin', 'my_secret', '--boltdir', project],
                       outputter: Bolt::Outputter::Human)
      # This is kind of brittle and we look for "encrypted_value because this is really the identity task
      expect(result).to match(/"encrypted_value"=>"secret_msg"/)
    end
  end

  context 'when managing puppet libraries' do
    # TODO: how do we test this cheaply?
  end

  context 'when manageing puppet_library', docker: true do
    let(:plan) do
      <<~PLAN
        plan test_plan() {
          apply_prep('ubuntu_node')
        }
      PLAN
    end

    let(:inventory) { docker_inventory(root: true) }

    context 'with an unsupported hook' do
      let(:plugin_hooks) {
        {
          'puppet_library' => {
            'plugin' => 'identity'
          }
        }
      }

      it 'fails cleanly' do
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /Plugin identity does not support puppet_library/
        )
      end
    end

    context 'with an unknown plugin' do
      let(:plugin_hooks) {
        {
          'puppet_library' => {
            'plugin' => 'does_not_exist'
          }
        }
      }

      it 'fails cleanly' do
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /The task failed with exit code 1/
        )
      end
    end
  end
end
