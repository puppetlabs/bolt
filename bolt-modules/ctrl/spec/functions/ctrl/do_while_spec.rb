# frozen_string_literal: true

require 'spec_helper'

describe 'ctrl::do_while' do
  it {
    count = 0
    seq = [false, true, true]
    x = nil
    is_expected.to(run.with_lambda do
      count += 1
      x = seq.pop
    end)
    expect(x).to eq(false)
    expect(count).to eq(3)
  }
end
