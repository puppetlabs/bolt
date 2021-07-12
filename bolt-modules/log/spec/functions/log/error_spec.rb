# frozen_string_literal: true

require 'spec_helper'

describe 'log::error' do
  let(:executor)      { stub('executor', report_function_call: nil, publish_event: nil) }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled

    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it 'sends a log event to the executor' do
    executor.expects(:publish_event).with(
      type:    :log,
      level:   :error,
      message: 'This is an error message'
    )

    is_expected.to run.with_params('This is an error message')
  end

  it 'reports function call to analytics' do
    executor.expects(:report_function_call).with('log::error')
    is_expected.to run.with_params('This is an error message')
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that log::error is not available' do
      is_expected.to run.with_params('This is an error message')
                        .and_raise_error(/Plan language function 'log::error' cannot be used/)
    end
  end
end
