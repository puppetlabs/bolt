# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'using module based plugins' do
  include BoltSpec::Files
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

  let(:config) {
    { 'modulepath' => ['modules', File.join(__dir__, '../../fixtures/plugin_modules')],
      "plugins" => plugin_config }
  }

  let(:plan) do
    <<~PLAN
      plan test_plan() {
        return(get_target('node1').password)
      }
    PLAN
  end

  let(:inventory) { { "version" => 2 } }

  around(:each) do |example|
    with_boltdir(inventory: inventory, config: config, plan: plan) do |boltdir|
      @boltdir = boltdir
      example.run
    end
  end

  let(:boltdir) { @boltdir }

  context 'when resolving references' do
    let(:plugin) {
      {
        '_plugin' => 'identity',
        'value' => "ssshhh"
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
      output = run_cli(['plan', 'run', 'test_plan', '--boltdir', boltdir])

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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', boltdir], rescue_exec: true)

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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', boltdir], rescue_exec: true)

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
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', boltdir], rescue_exec: true)

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
      { 'version' => 2,
        'targets' => [
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

    it 'fails when configuration is incorrect' do
      result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', boltdir], rescue_exec: true)

      expect(result).to include('kind' => "bolt/validation-error")
      expect(result['msg']).to match(/conf_plug plugin expects a String for key required_key/)
    end

    context 'with correct config' do
      let(:plugin_config) { { 'conf_plug' => { 'required_key' => 'foo' } } }

      it 'passes _config to the task' do
        result = run_cli_json(['plan', 'run', 'test_plan', '--boltdir', boltdir])

        expect(result['remote']['data']).to include('_config' => plugin_config['conf_plug'])
        expect(result['remote']['data']).to include('_boltdir' => boltdir)
        expect(result['remote']['data']).to include('value' => 'ssshhh')
      end
    end
  end

  context 'when handling secrets' do
    it 'calls the encrypt task' do
      result = run_cli(['secret', 'encrypt', 'secret_msg', '--plugin', 'my_secret', '--boltdir', boltdir],
                       outputter: Bolt::Outputter::Human)
      # This is kind of brittle and we look for plaintext_value because this is really the identity task
      expect(result).to match(/"plaintext_value"=>"secret_msg"/)
    end

    it 'calls the decrypt task' do
      result = run_cli(['secret', 'decrypt', 'secret_msg', '--plugin', 'my_secret', '--boltdir', boltdir],
                       outputter: Bolt::Outputter::Human)
      # This is kind of brittle and we look for "encrypted_value because this is really the identity task
      expect(result).to match(/"encrypted_value"=>"secret_msg"/)
    end
  end

  context 'when managing puppet libraries' do
    # TODO: how do we test this cheaply?
  end
end
