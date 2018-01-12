require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/pal'

require 'bolt/pal'
# TODO: clean this up
require 'bolt/cli'

describe 'Target DataType' do
  include BoltSpec::Files
  include BoltSpec::PAL

  before(:all) { Bolt::PAL.load_puppet }
  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:pal) { Bolt::PAL.new(config) }

  it 'should expose uri' do
    code = <<PUPPET
$target = Target('pcp://example.com')
$target.uri
PUPPET
    expect(peval(code, pal)).to eq('pcp://example.com')
  end

  it 'should expose name' do
    code = <<PUPPET
$target = Target('pcp://example.com')
$target.name
PUPPET
    expect(peval(code, pal)).to eq('pcp://example.com')
  end

  it 'should expose target' do
    code = <<PUPPET
$target = Target('pcp://example.com')
$target.options
PUPPET
    expect(peval(code, pal)).to eq({})
  end
end
