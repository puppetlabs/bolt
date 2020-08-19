# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/config'
require 'bolt/pal'
require 'bolt/plugin'
require 'bolt/analytics'

describe Bolt::Plugin do
  include BoltSpec::Files
  include BoltSpec::Config

  let(:modulepath) { [fixtures_path('plugin_modules')] }
  let(:plugin_config) { {} }
  let(:config_data) { { 'modulepath' => modulepath, 'plugins' => plugin_config } }
  let(:pal) { Bolt::PAL.new(Bolt::Config::Modulepath.new(modulepath), nil, nil) }

  let(:plugins) { Bolt::Plugin.setup(config(config_data), pal) }

  def identity(value)
    {
      '_plugin' => 'identity',
      'value' => value
    }
  end

  it 'loads an empty plugin module' do
    expect(plugins.by_name('empty_plug').hooks).to eq([:validate_resolve_reference])
  end

  it 'fails to load a non-plugin module' do
    expect { plugins.add_module_plugin('no_plug') }.to raise_exception(Bolt::Plugin::PluginError::Unknown)
    expect(plugins.by_name('no_plug')).to be_nil
  end

  it 'loads a plugin module' do
    plugins.add_module_plugin('my_plug')
    hooks = plugins.by_name('my_plug').hooks

    expect(hooks).to include(:resolve_reference)
    expect(hooks).to include(:createkeys)
    expect(hooks).not_to include(:decrypt)
  end

  context 'evaluating plugin config' do
    it 'lets a plugin depend on another plugin' do
      plugin_config.replace('pkcs7' => { 'keysize' => identity(1024) })
      expect { plugins }.not_to raise_error
    end

    it 'fails if a plugin depends on itself' do
      plugin_config.replace('identity' => { 'foo' => identity('bar') })
      expect { plugins }.to raise_error(/Configuration for plugin 'identity' depends on the plugin itself/)
    end

    it 'fails if an indirect plugin dependency cycle is found' do
      plugin_config.replace('pkcs7' => { 'keysize' => identity(1024) },
                            'identity' => { 'foo' => { '_plugin' => 'pkcs7' } })
      expect { plugins }.to raise_error(/Configuration for plugin 'pkcs7' depends on the plugin itself/)
    end
  end

  context 'loading plugin_hooks' do
    it 'evaluates plugin references in the plugin_hooks configuration' do
      config_data['plugin_hooks'] = {
        'puppet_library' => {
          'plugin' => 'my_hook',
          'param' => identity('foobar')
        }
      }
      expect(plugins.plugin_hooks['puppet_library']).to eq('plugin' => 'my_hook', 'param' => 'foobar')
    end

    it 'allows the whole plugin_hooks value to be set with a reference' do
      hooks = {
        'another_hook' => {
          'plugin' => 'my_hook',
          'param' => identity('foobar')
        }
      }

      config_data['plugin_hooks'] = identity(hooks)

      expect(plugins.plugin_hooks).to eq(
        'another_hook' => {
          'plugin' => 'my_hook',
          'param' => 'foobar'
        },
        'puppet_library' => {
          'plugin' => 'puppet_agent',
          'stop_service' => true
        }
      )
    end
  end
end
