# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
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

  it 'reports the call to analytics' do
    executor = Bolt::Executor.new
    executor.expects(:report_function_call).with('fail_plan')

    Puppet.override(bolt_executor: executor) do
      is_expected.to run.with_params('foo').and_raise_error(Bolt::PlanFailure)
    end
  end
end
