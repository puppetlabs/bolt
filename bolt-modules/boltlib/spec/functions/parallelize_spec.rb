# frozen_string_literal: true

require 'spec_helper'
require 'puppet_pal'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/plan_result'
# require 'bolt/plugin'
# require 'puppet/pops/types/p_sensitive_type'

describe 'parallelize' do
  include PuppetlabsSpec::Fixtures
  let(:array) { %w[a b c d] }
  let(:executor) { Bolt::Executor.new }
  let(:result_array) { %w[ea eb ec ed] }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it 'reports the function call to analytics' do
    executor.expects(:report_function_call).with('parallelize')

    array.each_with_index do |elem, index|
      yarn = mock('yarn', alive?: false, value: 'e' + elem, index: index)
      executor.expects(:create_yarn)
              .with(anything, anything, elem, index)
              .returns(yarn)
    end

    is_expected.to(run
      .with_params(array)
      .with_lambda { |elem| 'e' + elem })
  end

  it 'returns an array in order' do
    array.each_with_index do |elem, index|
      yarn = mock('yarn', alive?: false, value: 'e' + elem, index: index)
      executor.expects(:create_yarn)
              .with(anything, anything, elem, index)
              .returns(yarn)
    end

    is_expected.to(run
      .with_params(array)
      .with_lambda { |elem| 'e' + elem }
      .and_return(result_array))
  end

  context "with errors in the block" do
    it "returns a ParallelFailure" do
      error = Bolt::Error.new("error", 'bolt/test-failure')

      array.each_with_index do |elem, index|
        yarn = mock('yarn', alive?: false, value: error, index: index)
        executor.expects(:create_yarn)
                .with(anything, anything, elem, index)
                .returns(yarn)
      end

      is_expected.to(run
        .with_params(array)
        .with_lambda { |elem| 'e' + elem }
        .and_raise_error(Bolt::ParallelFailure, /parallel block failed on 4 targets/))
    end
  end
end
