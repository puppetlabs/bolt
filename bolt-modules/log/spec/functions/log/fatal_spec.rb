# frozen_string_literal: true

require 'spec_helper'

describe 'log::fatal' do
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
      level:   :fatal,
      message: 'This is a fatal message'
    )

    is_expected.to run.with_params('This is a fatal message')
  end

  it 'reports function call to analytics' do
    executor.expects(:report_function_call).with('log::fatal')
    is_expected.to run.with_params('This is a fatal message')
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that log::fatal is not available' do
      is_expected.to run.with_params('This is a fatal message')
                        .and_raise_error(/Plan language function 'log::fatal' cannot be used/)
    end
  end
end
