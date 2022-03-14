# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'using the task plugin' do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:plugin_hooks)  { {} }
  let(:project_name)  { 'task_test' }
  let(:command)       { %W[plan run #{project_name} --project #{@project.path}] }
  let(:config) do
    {
      'modulepath' => [fixtures_path('modules')],
      'plugin-hooks' => plugin_hooks
    }
  end

  let(:plan) do
    <<~PLAN
      plan #{project_name}() {
        return(get_targets('node1')[0].password)
      }
    PLAN
  end

  around(:each) do |example|
    with_project(project_name, inventory: inventory, config: config) do |project|
      @project = project
      FileUtils.mkdir_p(project.plans_path)
      File.write(File.join(project.plans_path, 'init.pp'), plan)

      example.run
    end
  end

  before :each do
    # Don't print error messages to the console
    allow($stdout).to receive(:puts)
  end

  context 'with a config lookup' do
    let(:plugin) do
      {
        '_plugin' => 'task',
        'task' => 'identity',
        'parameters' => {
          'value' => 'ssshhh'
        }
      }
    end

    let(:inventory) do
      { 'targets' => [
        { 'uri' => 'node1',
          'config' => {
            'ssh' => {
              'user' => 'me',
              'password' => plugin
            }
          } }
      ] }
    end

    it 'supports a config lookup' do
      output = run_cli(command)
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
        result = run_cli_json(command, rescue_exec: true)

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
        result = run_cli_json(command, rescue_exec: true)

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
      output = run_cli(command)

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
        result = run_cli_json(command)
        expect(result['msg']).to match(/Task result did not return 'value'/)
      end

      context 'execution fails' do
        let(:params) { { 'bad-key' => %w[foo bar] } }

        it 'errors' do
          result = run_cli_json(command)
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
          result = run_cli_json(command)
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
        plan #{project_name}(TargetSpec $nodes) {
          apply_prep($nodes)
        }
      PLAN
    end

    context 'with a failing task' do
      it 'fails cleanly' do
        result = run_cli_json(command + %w[--targets agentless], rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /The task failed with exit code 1/
        )
      end
    end

    context 'with invalid parameters' do
      let(:task) { 'sample::params' }

      it 'fails cleanly' do
        result = run_cli_json(command + %w[--targets agentless], rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /Error executing plugin task from puppet_library.*expects a value for parameter/m
        )
      end
    end

    context 'with a non-existent task' do
      let('task') { 'non_existent_task' }

      it 'fails cleanly' do
        result = run_cli_json(command + %w[--targets agentless], rescue_exec: true)

        expect(result).to include('kind' => "bolt/run-failure")
        expect(result['msg']).to match(/apply_prep failed on 1 target/)
        expect(result['details']['result_set'][0]['value']['_error']['msg']).to match(
          /Could not find a task named 'non_existent_task'/
        )
      end
    end
  end
end
