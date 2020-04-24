# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'using the task plugin' do
  include BoltSpec::Integration
  include BoltSpec::Conn

  def with_project(config: nil, inventory: nil, plan: nil)
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

  let(:plugin_hooks) { {} }

  let(:config) {
    {
      'modulepath' => ['modules', File.join(__dir__, '../../fixtures/modules')],
      'plugin_hooks' => plugin_hooks
    }
  }

  let(:plan) do
    <<~PLAN
      plan test_plan() {
        return(get_targets('node1')[0].password)
      }
    PLAN
  end

  attr_reader :project
  around(:each) do |example|
    with_project(inventory: inventory, config: config, plan: plan) do |project|
      @project = project
      example.run
    end
  end

  context 'with a config lookup' do
    let(:plugin) {
      {
        '_plugin' => 'task',
        'task' => 'identity',
        'parameters' => {
          'value' => 'ssshhh'
        }
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
          '_plugin' => 'task',
          'task' => 'sample::params',
          'parameters' => {
            'value' => 'ssshhh'
          }
        }
      }

      it 'errors when the parameters dont match' do
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

        expect(result).to include('kind' => "bolt/validation-error")
        expect(result['msg']).to match(/expects a value for parameter/)
      end
    end

    context 'with a bad result' do
      let(:plugin) {
        {
          '_plugin' => 'task',
          'task' => 'identity',
          'parameters' => {
            'not_value' => 'ssshhh'
          }
        }
      }

      it 'errors when the result is unexpected' do
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

        expect(result).to include('kind' => "bolt/plugin-error")
        expect(result['msg']).to match(/Task result did not return 'value'/)
      end
    end
  end

  context 'with a target lookup' do
    let(:plugin) {
      {
        '_plugin' => 'task',
        'task' => 'identity',
        'parameters' => {
          'value' => [
            {
              'uri' => 'node1',
              'config' => {
                'ssh' => {
                  'user' => 'me',
                  'password' => 'ssshhh'
                }
              }
            }
          ]
        }
      }
    }

    let(:inventory) {
      { 'targets' => [plugin] }
    }
    it 'supports a target lookup' do
      output = run_cli(['plan', 'run', 'test_plan', '--boltdir', project])

      expect(output.strip).to eq('"ssshhh"')
    end

    context 'with a bad lookup' do
      let(:params) { { 'not_value' => [] } }

      let(:plugin) {
        {
          '_plugin' => 'task',
          'task' => 'identity',
          'parameters' => params
        }
      }

      it 'errors when the result is unexpected' do
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

        expect(result).to include('kind' => "bolt/plugin-error")
        expect(result['msg']).to match(/Task result did not return 'value'/)
      end

      context 'execution fails' do
        let(:params) { { 'bad-key' => %w[foo bar] } }
        it 'errors' do
          result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

          expect(result).to include('kind' => "bolt/validation-error")
          expect(result['msg']).to match(/bad-key/)
        end
      end

      context 'when the task fails' do
        let(:plugin) {
          {
            '_plugin' => 'task',
            'task' => 'error::fail',
            'parameters' => params
          }
        }
        it 'errors when the task fails' do
          result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', project], rescue_exec: true)

          expect(result).to include('kind' => "bolt/plugin-error")
          expect(result['msg']).to match(/The task failed/)
        end
      end
    end
  end

  # Because the only way we have to test this and apply_prep will fail to
  # gather facts these can only test error cases now.
  context 'With a puppet_library call', docker: true do
    let(:task) { 'error::fail' }
    let(:parameters) { {} }
    let(:inventory) { docker_inventory(root: true) }

    let(:plugin_hooks) {
      {
        'puppet_library' => {
          'plugin' => 'task',
          'task' => task,
          'parameters' => parameters
        }
      }
    }

    let(:plan) do
      <<~PLAN
        plan test_plan(TargetSpec $nodes) {
          apply_prep($nodes)
        }
      PLAN
    end

    context 'with a failing task' do
      it 'fails cleanly' do
        result = run_cli_json(['plan', 'run',
                               'test_plan', '--targets', 'agentless', '--boltdir', project],
                              rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /The task failed with exit code 1/
        )
      end
    end

    context 'with invalid parameters' do
      let(:task) { 'sample::params' }

      it 'fails cleanly' do
        result = run_cli_json(['plan', 'run',
                               'test_plan', '--targets', 'agentless', '--boltdir', project],
                              rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /Invalid parameters for Task sample::params/
        )
      end
    end

    context 'with a non-existent task' do
      let('task') { 'non_existent_task' }

      it 'fails cleanly' do
        result = run_cli_json(['plan', 'run',
                               'test_plan', '--targets', 'agentless', '--boltdir', project],
                              rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/Plan aborted: apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /Task 'non_existent_task' could not be found/
        )
      end
    end
  end
end
