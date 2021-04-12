# frozen_string_literal: true

require 'spec_helper'
require 'puppet_pal'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/plan_result'

describe 'parallelize' do
  include PuppetlabsSpec::Fixtures
  let(:array) { %w[a b c d a b a] }
  let(:future) { Bolt::PlanFuture.new(nil, 1, 'name') }
  let(:executor) { Bolt::Executor.new }
  let(:result_array) { %w[ea eb ec ed ea eb ea] }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  before :each do
    array.each do
      executor.expects(:create_future).returns(future)
    end
    executor.expects(:wait).returns(result_array)
  end

  it 'reports the function call to analytics' do
    executor.expects(:report_function_call).with('parallelize')

    is_expected.to(run
      .with_params(array)
      .with_lambda { |obj| 'e' + obj })
  end

  it 'returns the results from the executor' do
    is_expected.to(run
      .with_params(array)
      .with_lambda { |obj| 'e' + obj }
      .and_return(result_array))
  end
end
