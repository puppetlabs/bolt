# frozen_string_literal: true

require 'spec_helper'
require 'puppet_pal'
require 'bolt/executor'
require 'bolt/plan_future'

describe 'wait' do
  include PuppetlabsSpec::Fixtures
  let(:name)      { "Pluralize" }
  let(:future)    { Bolt::PlanFuture.new('foo', name) }
  let(:executor)  { Bolt::Executor.new }
  let(:result)    { ['return'] }
  let(:timeout)   { 2 }
  let(:options)   { { '_catch_errors' => true } }
  let(:sym_opts)  { { catch_errors: true } }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it 'reports the function call to analytics' do
    executor.expects(:report_function_call).with('wait')
    executor.expects(:wait).with([future]).returns(result)

    is_expected.to(run
      .with_params(future))
  end

  it 'turns a single object into an array' do
    executor.expects(:wait).with([future]).returns(result)

    is_expected.to(run
      .with_params(future)
      .and_return(result))
  end

  it 'runs with a timeout specified' do
    executor.expects(:wait)
            .with([future], { timeout: timeout }).returns(result)

    is_expected.to(run
      .with_params(future, timeout)
      .and_return(result))
  end

  it 'runs with only options specified' do
    executor.expects(:wait)
            .with([future], sym_opts).returns(result)

    is_expected.to(run
      .with_params(future, options)
      .and_return(result))
  end

  it 'runs with timeout and options specified' do
    executor.expects(:wait)
            .with([future], sym_opts.merge({ timeout: timeout })).returns(result)

    is_expected.to(run
      .with_params(future, timeout, options)
      .and_return(result))
  end

  it 'filters out invalid options' do
    executor.expects(:wait).with([future]).returns(result)
    Bolt::Logger.expects(:warn)
                .with('plan_function_options', anything)

    is_expected.to(run
      .with_params(future, { 'timeout' => 2 })
      .and_return(result))
  end
end
