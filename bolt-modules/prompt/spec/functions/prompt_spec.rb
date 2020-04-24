# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'

describe 'prompt' do
  let(:executor)      { Bolt::Executor.new }
  let(:prompt)        { 'prompt' }
  let(:response)      { 'response' }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) { example.run }
  end

  it 'returns a String value' do
    executor.expects(:prompt).with(prompt, {}).returns(response)
    is_expected.to run.with_params(prompt).and_return(response)
  end

  it 'returns a Sensitive value' do
    executor.expects(:prompt).with(prompt, sensitive: true).returns(response)

    result = subject.execute(prompt, 'sensitive' => true)

    expect(result.class).to be(Puppet::Pops::Types::PSensitiveType::Sensitive)
    expect(result.unwrap).to eq(response)
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(1)
                      .and_raise_error(ArgumentError,
                                       "'prompt' parameter 'prompt' expects a String value, got Integer")
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('prompt')
    executor.expects(:prompt).with(prompt, {}).returns(response)
    is_expected.to run.with_params(prompt)
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that prompt is not available' do
      is_expected.to run.with_params(prompt)
                        .and_raise_error(/Plan language function 'prompt' cannot be used/)
    end
  end
end
