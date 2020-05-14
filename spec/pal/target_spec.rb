# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt_spec/config'

require 'bolt/pal'
require 'bolt/inventory'
require 'bolt/plugin'

describe 'Target DataType' do
  include BoltSpec::Files
  include BoltSpec::PAL
  include BoltSpec::Config

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:pal)     { Bolt::PAL.new(modulepath, nil, nil) }
  let(:plugins) { Bolt::Plugin.setup(config, nil) }

  let(:target_code) { "$target = Target('pcp://user1:pass1@example.com:33')\n" }

  let(:default_config) { config.transports['pcp'].to_h }

  def target(attr)
    code = target_code + attr
    peval(code, pal, nil, Bolt::Inventory::Inventory.new({}, config.transport, config.transports, plugins))
  end

  it 'should expose uri' do
    expect(target('$target.uri')).to eq('pcp://user1:pass1@example.com:33')
  end

  it 'should expose name' do
    expect(target('$target.name')).to eq('pcp://user1:pass1@example.com:33')
  end

  it 'should expose host' do
    expect(target('$target.host')).to eq('example.com')
  end

  it 'should expose protocol' do
    expect(target('$target.protocol')).to eq('pcp')
  end

  it 'should expose port' do
    expect(target('$target.port')).to eq(33)
  end

  it 'should expose user' do
    expect(target('$target.user')).to eq('user1')
  end

  it 'should expose password' do
    expect(target('$target.password')).to eq('pass1')
  end

  it 'should expose transport' do
    expect(target('$target.transport')).to eq('pcp')
  end

  it 'should expose transport_config' do
    expect(target('$target.transport_config')).to eq(default_config)
  end
end
