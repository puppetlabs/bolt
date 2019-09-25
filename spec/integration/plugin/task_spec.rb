# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'using the task plugin' do
  include BoltSpec::Files
  include BoltSpec::Integration

  def with_boltdir(config: nil, inventory: nil)
    Dir.mktmpdir do |tmpdir|
      File.write(File.join(tmpdir, 'bolt.yaml'), config.to_yaml) if config
      File.write(File.join(tmpdir, 'inventory.yaml'), inventory.to_yaml) if inventory
      yield tmpdir
    end
  end

  let(:config) { { 'modulepath' => ['modules', File.join(__dir__, '../../fixtures/modules')] } }

  let(:plan) do
    <<~PLAN
      plan passw() {
        return(get_targets('node1')[0].password)
      }
    PLAN
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
      { 'version' => 2,
        'targets' => [
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
      with_boltdir(inventory: inventory, config: config) do |boltdir|
        plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
        FileUtils.mkdir_p(plan_dir)
        File.write(File.join(plan_dir, 'init.pp'), plan)
        output = run_cli(['plan', 'run', 'passw', '--boltdir', boltdir])

        expect(output.strip).to eq('"ssshhh"')
      end
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
        with_boltdir(inventory: inventory, config: config) do |boltdir|
          plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
          FileUtils.mkdir_p(plan_dir)
          File.write(File.join(plan_dir, 'init.pp'), plan)
          result = run_cli_json(['plan', 'run', 'passw', '--boltdir', boltdir], rescue_exec: true)

          expect(result).to include('kind' => "bolt/validation-error")
          expect(result['msg']).to match(/expects a value for parameter/)
        end
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
        with_boltdir(inventory: inventory, config: config) do |boltdir|
          plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
          FileUtils.mkdir_p(plan_dir)
          File.write(File.join(plan_dir, 'init.pp'), plan)
          result = run_cli_json(['plan', 'run', 'passw', '--boltdir', boltdir], rescue_exec: true)

          expect(result).to include('kind' => "bolt/plugin-error")
          expect(result['msg']).to match(/Task result did not return 'value'/)
        end
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
      { 'version' => 2,
        'targets' => [plugin] }
    }
    it 'supports a target lookup' do
      with_boltdir(inventory: inventory, config: config) do |boltdir|
        plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
        FileUtils.mkdir_p(plan_dir)
        File.write(File.join(plan_dir, 'init.pp'), plan)
        output = run_cli(['plan', 'run', 'passw', '--boltdir', boltdir])

        expect(output.strip).to eq('"ssshhh"')
      end
    end

    context 'with a bad lookup' do
      let(:plugin) {
        {
          '_plugin' => 'task',
          'task' => 'identity',
          'parameters' => {
            'not_value' => []
          }
        }
      }

      it 'errors when the result is unexpected' do
        with_boltdir(inventory: inventory, config: config) do |boltdir|
          plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
          FileUtils.mkdir_p(plan_dir)
          File.write(File.join(plan_dir, 'init.pp'), plan)
          result = run_cli_json(['plan', 'run', 'passw', '--boltdir', boltdir], rescue_exec: true)

          expect(result).to include('kind' => "bolt/plugin-error")
          expect(result['msg']).to match(/Task result did not return 'value'/)
        end
      end

      it 'errors when targets are strings' do
        inventory['targets'][0]['parameters']['value'] = %w[foo bar]
        with_boltdir(inventory: inventory, config: config) do |boltdir|
          plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
          FileUtils.mkdir_p(plan_dir)
          File.write(File.join(plan_dir, 'init.pp'), plan)
          result = run_cli_json(['plan', 'run', 'passw', '--boltdir', boltdir], rescue_exec: true)

          expect(result).to include('kind' => "bolt.inventory/validation-error")
          expect(result['msg']).to match(/Node entry must be a Hash, not String/)
        end
      end

      it 'errors when execution fails' do
        inventory['targets'][0]['parameters']['bad-key'] = 10
        with_boltdir(inventory: inventory, config: config) do |boltdir|
          plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
          FileUtils.mkdir_p(plan_dir)
          File.write(File.join(plan_dir, 'init.pp'), plan)
          result = run_cli_json(['plan', 'run', 'passw', '--boltdir', boltdir], rescue_exec: true)

          expect(result).to include('kind' => "bolt/plugin-error")
          expect(result['msg']).to match(/bad-key/)
        end
      end

      it 'errors when the task fails' do
        inventory['targets'][0]['task'] = 'error::fail'
        with_boltdir(inventory: inventory, config: config) do |boltdir|
          plan_dir = File.join(boltdir, 'modules', 'passw', 'plans')
          FileUtils.mkdir_p(plan_dir)
          File.write(File.join(plan_dir, 'init.pp'), plan)
          result = run_cli_json(['plan', 'run', 'passw', '--boltdir', boltdir], rescue_exec: true)

          expect(result).to include('kind' => "bolt/plugin-error")
          expect(result['msg']).to match(/The task failed/)
        end
      end
    end
  end
end
