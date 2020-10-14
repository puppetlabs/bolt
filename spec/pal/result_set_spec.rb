# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt_spec/config'

require 'bolt/pal'
require 'bolt/inventory/inventory'
require 'bolt/plugin'

describe 'ResultSet DataType' do
  include BoltSpec::Files
  include BoltSpec::PAL
  include BoltSpec::Config

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:pal)     { Bolt::PAL.new(Bolt::Config::Modulepath.new(modulepath), nil, nil) }
  let(:plugins) { Bolt::Plugin.setup(config, nil) }

  let(:result_code) do
    <<~PUPPET
      $result_set = results::make_result_set( {
        'pcp://example1.com' => {'key' => 'value' },
        'example2.com' => { 'key' => 'value' } } )
    PUPPET
  end

  def result_set(attr)
    code = result_code + attr
    peval(code, pal, nil, Bolt::Inventory::Inventory.new({}, config.transport, config.transports, plugins))
  end

  it 'should be ok' do
    expect(result_set('$result_set.ok')).to eq(true)
  end

  it 'should count to 2' do
    expect(result_set('$result_set.count')).to eq(2)
  end

  it 'should have 2 in the ok_set' do
    expect(result_set('$result_set.ok_set.count')).to eq(2)
  end

  it 'should return first' do
    expect(result_set('$result_set.first.target.uri')).to eq('pcp://example1.com')
  end

  it 'should have an empty error_set' do
    expect(result_set('$result_set.error_set.empty')).to eq(true)
  end

  it 'should expose targets' do
    expect(result_set('$result_set.targets.map |$t| {$t.uri}')).to eq(['pcp://example1.com', 'example2.com'])
  end

  it 'should expose names' do
    expect(result_set('$result_set.names')).to eq(['pcp://example1.com', 'example2.com'])
  end

  it 'should find results by target name' do
    expect(result_set("$result_set.find('example2.com').target.name")).to eq('example2.com')
  end

  it 'should be iterable' do
    expect(result_set('$result_set.map |$r| {$r.target.uri}')).to eq(['pcp://example1.com', 'example2.com'])
  end

  context 'when there are errors' do
    let(:result_code) do
      <<-PUPPET
$result_set = results::make_result_set( {
  'pcp://example1.com' => {'key' => 'value'},
  'ssh://example2.com' => {'_error' => {
                               'kind' => 'bolt/oops',
                               'msg' => 'oops' } },
  'winrm://win.com' => { 'key2' => 'value',
                         '_error' => {
                               'kind' => 'bolt/oops',
                               'msg' => 'oops',
                               'details' => {
                                 'detailk' => 'value' } } },
  'example3.com' => { 'key' => 'value' } } )
PUPPET
    end

    it 'should not be ok' do
      expect(result_set('$result_set.ok')).to eq(false)
    end

    it 'should have an error_set' do
      expect(result_set('$result_set.error_set.count')).to eq(2)
    end

    it 'should have an ok_set' do
      expect(result_set('$result_set.ok_set.count')).to eq(2)
    end
  end
end
