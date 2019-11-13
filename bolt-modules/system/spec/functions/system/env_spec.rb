# frozen_string_literal: true

require 'spec_helper'

describe 'system::env' do
  it {
    is_expected.to run.with_params('USER').and_return(ENV['USER'])
  }

  it "doesn't error for unknown envars" do
    is_expected.to run.with_params('thiskeyprobablydoesntexistanywhere').and_return(nil)
  end
end
