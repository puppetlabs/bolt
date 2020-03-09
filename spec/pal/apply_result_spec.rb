# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'
require 'bolt_spec/config'

require 'bolt/pal'
require 'bolt/inventory'
require 'bolt/plugin'

describe 'ApplyResult DataType' do
  include BoltSpec::Files
  include BoltSpec::PAL
  include BoltSpec::Config

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:pal)     { Bolt::PAL.new(modulepath, nil, nil) }
  let(:plugins) { Bolt::Plugin.setup(config, nil, nil, Bolt::Analytics::NoopClient.new) }

  let(:result_code) do
    <<~PUPPET
      $result = results::make_apply_result('pcp://example.com', {'report' => {}})
    PUPPET
  end

  def result_attr(attr)
    code = result_code + attr
    peval(code, pal, nil, Bolt::Inventory::Inventory.new({}, config.transport, config.transports, plugins))
  end

  it 'should expose target' do
    expect(result_attr('$result.target.uri')).to eq('pcp://example.com')
  end

  it 'should expose the report' do
    expect(result_attr('$result.report')).to eq({})
  end

  it 'should be ok' do
    expect(result_attr('$result.ok')).to eq(true)
  end

  context 'with an error result' do
    let(:result_code) do
      <<~PUPPET
        $result = results::make_result('pcp://example.com',
                    { '_error' => {
                        'msg' => 'oops',
                        'kind' => 'bolt/oops',
                        'details' => {'detailk' => 'detailv'}
                        }
                    })
      PUPPET
    end

    it 'should not be ok' do
      expect(result_attr('$result.ok')).to eq(false)
    end

    it 'should expose the error kind' do
      expect(result_attr('$result.error.kind')).to eq('bolt/oops')
    end

    it 'should expose the error message' do
      expect(result_attr('$result.error.message')).to eq('oops')
    end

    it 'should expose the error kind' do
      expect(result_attr("$result.error.details['detailk']")).to eq('detailv')
    end
  end
end
