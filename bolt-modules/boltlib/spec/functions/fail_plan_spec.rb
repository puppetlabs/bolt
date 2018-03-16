# frozen_string_literal: true

require 'spec_helper'
require 'bolt/error'

describe 'fail_plan' do
  include PuppetlabsSpec::Fixtures

  it 'raises an error from arguments' do
    is_expected.to run.with_params('oops').and_raise_error(Bolt::PlanFailure)
  end

  it 'raises an error from an Error object' do
    error = Puppet::DataTypes::Error.new('oops')
    is_expected.to run.with_params(error).and_raise_error(Bolt::PlanFailure)
  end
end
