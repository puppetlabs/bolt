# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/config'
require 'bolt/plugin'
require 'bolt/analytics'

describe Bolt::Plugin::Module do
  include BoltSpec::Files
  include BoltSpec::Config

  let(:modulepath) { [fixtures_path('plugin_modules')] }
  let(:plugin_config) { {} }
  let(:config_data) { { 'modulepath' => modulepath, 'plugins' => plugin_config } }

  let(:pal) { Bolt::PAL.new(modulepath, {}, nil) }
  let(:plugins) { Bolt::Plugin.setup(config(config_data), pal) }

  let(:module_name) { 'empty_plug' }
  let(:mod) { Bolt::Module.new(module_name, fixtures_path('plugin_modules', module_name)) }

  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.new({}) }
  let(:plugin_data) { {} }

  let(:plugin) do
    plug = Bolt::Plugin::Module.new(context: plugins.plugin_context,
                                    mod: mod,
                                    config: plugin_config)

    plug.instance_variable_set(:@data, plugin_data)
    plug
  end

  describe(:process_schema) do
    it 'loads empty schema' do
      expect(plugin.process_schema({})).to eq({})
    end

    it 'errors with an invalid config' do
      expect { plugin.process_schema('string') }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors with an invalid config entry' do
      schema = { "key" => [] }
      expect { plugin.process_schema(schema) }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors with an invalid type' do
      schema = { "key" => { 'type' => 'NotAType' } }
      expect { plugin.process_schema(schema) }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors with an invalid type' do
      schema = { "key" => { 'type' => 'invalid string here%' } }
      expect { plugin.process_schema(schema) }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'accepts a valid type' do
      schema = { "key" => { 'type' => 'String' } }
      expect(plugin.process_schema(schema)).to include('key')
    end
  end

  describe(:find_hooks) do
    it 'errors when hooks is not a hash' do
      expect { plugin.find_hooks('string') }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors when a hook is not a hash' do
      expect { plugin.find_hooks('secret_decrypt' => 'string') }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors when a hook does not have a task' do
      expect { plugin.find_hooks('secret_decrypt' => {}) }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors when a hook specifies an invalid task name' do
      expect { plugin.find_hooks('secret_decrypt' => { 'task' => "&&bad**" }) }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    it 'errors when a hook specifies an unknown task name' do
      expect { plugin.find_hooks('secret_decrypt' => { 'task' => "dne" }) }.to raise_error(
        Bolt::Plugin::Module::InvalidPluginData
      )
    end

    context 'with hooks in tasks' do
      let(:module_name) { 'my_plug' }

      it 'finds task based hooks' do
        hooks = plugin.find_hooks({})
        expect(hooks[:resolve_reference]["task"].name).to eq("my_plug::resolve_reference")
      end

      it 'honors explicit hooks over implicit' do
        hooks = plugin.find_hooks('resolve_reference' => { 'task' => "identity" })
        expect(hooks[:resolve_reference]["task"].name).to eq("identity")
      end
    end
  end

  describe(:validate_config) do
    let(:config_schema) { plugin.process_schema('conf_key' => { 'type' => 'String' }) }

    it 'accepts a valid config' do
      expect(plugin.validate_config({ 'conf_key' => 'bar' }, config_schema)).to eq(nil)
    end

    it 'errors with a bad value' do
      expect { plugin.validate_config({ 'conf_key' => 10 }, config_schema) }.to raise_error(
        Bolt::ValidationError
      )
    end

    it 'errors with a missing key' do
      expect { plugin.validate_config({}, config_schema) }.to raise_error(Bolt::ValidationError)
    end

    it 'errors with an unexpected value' do
      expect { plugin.validate_config({ 'conf_key' => 'bar', 'unexp' => "key" }, config_schema) }.to raise_error(
        Bolt::ValidationError
      )
    end
  end
end
