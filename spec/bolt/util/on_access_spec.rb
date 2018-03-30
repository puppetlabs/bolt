# frozen_string_literal: true

require 'spec_helper'
require 'bolt/util/on_access'

describe Bolt::Util::OnAccess do
  it 'delays initialization' do
    obj = Bolt::Util::OnAccess.new do
      raise 'failed init'
    end

    expect {
      obj.length
    }.to raise_error('failed init')
  end

  it 'constructs an object and passes calls through' do
    obj = Bolt::Util::OnAccess.new do
      [1, 2, 3]
    end

    expect(obj.length).to eq(3)
    expect(obj[0]).to eq(1)
  end
end
