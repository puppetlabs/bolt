# frozen_string_literal: true

require 'spec_helper'

describe 'system::env' do
  it {
    is_expected.to run.with_params('USER').and_return(ENV['USER'])
  }
end
