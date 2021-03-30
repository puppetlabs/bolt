# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/bolt_context'

describe 'bolt_spec_spec::with_datatype' do
  include BoltSpec::BoltContext

  around :each do |example|
    in_bolt_context do
      example.run
    end
  end

  it "bolt_context runs a Puppet function with Bolt datatypes" do
    expect_out_message.with_params("Loaded TargetSpec localhost")
    is_expected.to run.with_params('localhost').and_return('localhost')
  end
end
