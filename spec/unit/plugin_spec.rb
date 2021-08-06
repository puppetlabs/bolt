# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/config'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt/pal'
require 'bolt/plugin'
require 'bolt/plugin/env_var'
require 'bolt/analytics'

describe Bolt::Plugin do
  include BoltSpec::Config
  include BoltSpec::Files
  include BoltSpec::PAL

  let(:plugin_config) { {} }
  let(:modulepath)    { [fixtures_path('plugin_modules')] }
  let(:config_data)   { { 'modulepath' => modulepath, 'plugins' => plugin_config } }
  let(:config)        { make_config(config_data) }
  let(:pal)           { make_pal(modulepath) }
  let(:plugins)       { Bolt::Plugin.new(config, pal) }

  def identity(value, cache = nil)
    plugin = {
      '_plugin' => 'identity',
      'value' => value
    }
    unless cache.nil?
      plugin.merge!({ '_cache' => cache })
    end
    plugin
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
    expect(hooks).to include(:secret_createkeys)
    expect(hooks).not_to include(:secret_decrypt)
  end

  context 'listing plugins' do
    let(:modulepath) { [fixtures_path('modules')] }

    it 'returns a list of all plugin hooks' do
      plugin_hooks = plugins.list_plugins
      plugin_names = plugin_hooks.values.map(&:keys).flatten.uniq

      expect(plugin_hooks.keys).to match_array(Bolt::Plugin::KNOWN_HOOKS),
                                   "Does not include all known hooks"
      expect(plugin_names).to include('env_var'),
                              "Does not include built-in Ruby plugins"
      expect(plugin_names).to include('plugin'),
                              "Does not include custom module plugins"
      expect(plugin_hooks.dig(:resolve_reference, 'plugin')).to eq('My custom plugin'),
                                                                "Does not include descriptions"
    end
  end

  context 'evaluating plugin config' do
    it 'lets a plugin depend on another plugin' do
      plugin_config.replace('pkcs7' => { 'keysize' => identity(1024) })
      expect { plugins }.not_to raise_error
    end

    it 'fails if a plugin depends on itself' do
      plugin_config.replace('identity' => { 'foo' => identity('bar') })
      expect { plugins.by_name('identity') }
        .to raise_error(/Configuration for plugin 'identity' depends on the plugin itself/)
    end

    it 'fails if an indirect plugin dependency cycle is found' do
      plugin_config.replace('pkcs7' => { 'keysize' => identity(1024) },
                            'identity' => { 'foo' => { '_plugin' => 'pkcs7' } })
      expect { plugins.by_name('pkcs7') }
        .to raise_error(/Configuration for plugin 'pkcs7' depends on the plugin itself/)
    end
  end

  context 'loading plugin hooks' do
    it 'evaluates plugin references in the plugin hooks configuration' do
      config_data['plugin-hooks'] = {
        'puppet_library' => {
          'plugin' => 'my_hook',
          'param' => identity('foobar')
        }
      }
      expect(plugins.plugin_hooks['puppet_library']).to eq('plugin' => 'my_hook', 'param' => 'foobar')
    end

    it 'allows the whole plugin hooks value to be set with a reference' do
      hooks = {
        'another_hook' => {
          'plugin' => 'my_hook',
          'param' => identity('foobar')
        }
      }

      config_data['plugin-hooks'] = identity(hooks)

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

  context 'plugin loading is disabled' do
    let(:plugins) { Bolt::Plugin.new(config, pal, load_plugins: false) }

    it 'raises a plugin-loading-disabled error if it attempts to load a Ruby plugin' do
      expect { plugins.by_name('env_var') }.to raise_error(
        Bolt::Plugin::PluginError::LoadingDisabled,
        /plugin.*env_var.*loading.*disabled/
      ) do |error|
        expect(error.details).to eql({ 'plugin_name' => 'env_var' })
      end
    end

    it 'raises an unknown-plugin error if it attempts to load an unknown plugin' do
      # by_name rescues unknown-plugin errors and returns nil for them so use get_hook instead. This should be OK
      # since get_hook wraps by_name and is what Bolt actually calls when evaluating inventory plugins
      expect { plugins.get_hook('unknown_plug', :resolve_reference) }.to raise_error(Bolt::Plugin::PluginError::Unknown)
    end

    it 'raises a plugin-loading-disabled error if it attempts to load a Module plugin' do
      expect { plugins.by_name('identity') }.to raise_error(Bolt::Plugin::PluginError::LoadingDisabled)
    end

    it 'lets users add their statically loaded plugins via add_plugin' do
      env_var_plugin = Bolt::Plugin::EnvVar.new
      plugins.add_plugin(env_var_plugin)
      expect(plugins.by_name('env_var')).to equal(env_var_plugin)
    end
  end
end
