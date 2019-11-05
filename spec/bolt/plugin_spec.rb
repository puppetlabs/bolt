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
  let(:pal) { Bolt::PAL.new(modulepath, nil, nil) }
  let(:pdb_client) { double('pdb_client') }

  let(:plugins) { Bolt::Plugin.setup(config(config_data), pal, pdb_client, Bolt::Analytics::NoopClient.new) }

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
      expect(plugins.by_name('pkcs7').keysize).to eq(1024)
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

    it 'fails if the entire plugins key is set with a reference' do
      plugin_config.replace(identity('pkcs7' => { 'keysize' => 1024 }))

      expect { plugins }.to raise_error(/The 'plugins' setting cannot be set by a plugin reference/)
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
      expect(plugins.default_plugin_hooks['puppet_library']).to eq('plugin' => 'my_hook', 'param' => 'foobar')
    end
  end
end
