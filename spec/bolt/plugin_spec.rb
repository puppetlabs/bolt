# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/config'
require 'bolt/pal'
require 'bolt/plugin'
require 'bolt/analytics'

# TODO: This is probably just for Bolt::Plugin::Module
describe Bolt::Plugin::Module do
  include BoltSpec::Files
  include BoltSpec::Config

  let(:modulepath) { [fixtures_path('plugin_modules')] }
  let(:plugin_config) { {} }
  let(:config_data) { { 'modulepath' => modulepath, 'plugins' => plugin_config } }
  let(:pal) { Bolt::PAL.new(modulepath, nil, nil) }

  let(:plugins) { Bolt::Plugin.new(config(config_data), pal, Bolt::Analytics::NoopClient.new) }

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
end
