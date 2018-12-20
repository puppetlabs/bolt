# frozen_string_literal: true

require 'spec_helper'

describe 'ctrl::do_until' do
  it {
    count = 0
    seq = [true, false, false]
    x = nil
    is_expected.to(run.with_lambda do
      count += 1
      x = seq.pop
    end)
    expect(x).to eq(true)
    expect(count).to eq(3)
  }
end
