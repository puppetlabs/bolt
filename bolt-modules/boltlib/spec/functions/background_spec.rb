# frozen_string_literal: true

require 'spec_helper'
require 'puppet_pal'
require 'bolt/executor'
require 'bolt/plan_future'

describe 'background' do
  include PuppetlabsSpec::Fixtures
  let(:name)      { "Pluralize" }
  let(:object)    { "noodle" }
  let(:future)    { Bolt::PlanFuture.new('foo', name) }
  let(:executor)  { Bolt::Executor.new }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it 'reports the function call to analytics' do
    executor.expects(:report_function_call).with('background')

    is_expected.to(run
      .with_params(name)
      .with_lambda { 'a' + 'b' })
  end

  it 'returns the PlanFuture the executor creates' do
    executor.expects(:create_future)
            .with(has_entries(scope: anything, name: name))
            .returns(future)

    is_expected.to(run
      .with_params(name)
      .with_lambda { 'a' + 'b' }
      .and_return(future))
  end
end
