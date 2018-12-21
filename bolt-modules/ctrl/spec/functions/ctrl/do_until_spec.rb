# frozen_string_literal: true

require 'spec_helper'

describe 'ctrl::do_until' do
  it {
    count = 0
    seq = ['something', false, false]
    is_expected.to(run.with_lambda do
      count += 1
      seq.pop
    end.and_return('something'))
    expect(count).to eq(3)
  }
end
