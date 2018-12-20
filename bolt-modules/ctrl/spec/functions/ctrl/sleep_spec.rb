# frozen_string_literal: true

require 'spec_helper'

describe 'ctrl::sleep' do
  it {
    now = Time.now
    is_expected.to run.with_params(1)
    expect(Time.now - now).to be >= 1
  }

  it {
    now = Time.now
    is_expected.to run.with_params(0.5)
    expect(Time.now - now).to be >= 0.5
  }
end
