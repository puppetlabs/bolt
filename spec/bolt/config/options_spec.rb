# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/options'
require 'bolt/config/options'

context 'Bolt::Config::Options::OPTIONS' do
  include BoltSpec::Options

  it 'has a type and description for each option' do
    expect(Bolt::Config::Options::OPTIONS.class).to eq(Hash)
    assert_type_description(Bolt::Config::Options::OPTIONS)
  end
end

context 'Bolt::Config::Options::INVENTORY_OPTIONS' do
  include BoltSpec::Options

  it 'has a type and description for each option' do
    expect(Bolt::Config::Options::INVENTORY_OPTIONS.class).to eq(Hash)
    assert_type_description(Bolt::Config::Options::INVENTORY_OPTIONS)
  end
end
