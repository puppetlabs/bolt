# frozen_string_literal: true

require 'spec_helper'

describe 'out::verbose' do
  let(:executor)      { stub('executor', report_function_call: nil, publish_event: nil) }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled

    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it 'sends a verbose event to the executor' do
    executor.expects(:publish_event).with(
      type:    :verbose,
      message: 'This is a message',
      level:   :debug
    )

    is_expected.to run.with_params('This is a message')
  end

  it 'reports function call to analytics' do
    executor.expects(:report_function_call).with('out::verbose')
    is_expected.to run.with_params('This is a message')
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that out::verbose is not available' do
      is_expected.to run.with_params('This is a message')
                        .and_raise_error(/Plan language function 'out::verbose' cannot be used/)
    end
  end
end
