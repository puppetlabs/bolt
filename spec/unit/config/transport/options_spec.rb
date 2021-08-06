# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/options'
require 'bolt/config/transport/options'

context 'Bolt::Config::Transport::Options::TRANSPORT_OPTIONS' do
  include BoltSpec::Options

  it 'has a type and description for each option' do
    expect(Bolt::Config::Transport::Options::TRANSPORT_OPTIONS.class).to eq(Hash)
    assert_type_description(Bolt::Config::Transport::Options::TRANSPORT_OPTIONS)
  end
end
