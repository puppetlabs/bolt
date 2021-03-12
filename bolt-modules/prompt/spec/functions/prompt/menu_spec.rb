# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'

describe 'prompt::menu' do
  let(:executor)      { Bolt::Executor.new }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor) { example.run }
  end

  it 'displays a menu from an array of options' do
    prompt = <<~PROMPT.chomp
      (1) apple
      (2) banana
      (3) carrot
      Select a fruit
    PROMPT

    executor.expects(:prompt).with(prompt, {}).returns('1')

    is_expected.to run
      .with_params('Select a fruit', %w[apple banana carrot])
      .and_return('apple')
  end

  it 'displays a menu from a hash of options' do
    prompt = <<~PROMPT.chomp
      (a) apple
      (b) banana
      (c) carrot
      Select a fruit
    PROMPT

    executor.expects(:prompt).with(prompt, {}).returns('a')

    is_expected.to run
      .with_params('Select a fruit', { 'a' => 'apple', 'b' => 'banana', 'c' => 'carrot' })
      .and_return('apple')
  end

  it 'aligns values' do
    prompt = <<~PROMPT.chomp
      (a)      apple
      (b)      banana
      (carrot) carrot
      Select a fruit
    PROMPT

    executor.expects(:prompt).with(prompt, {}).returns('a')

    is_expected.to run
      .with_params('Select a fruit', { 'a' => 'apple', 'b' => 'banana', 'carrot' => 'carrot' })
      .and_return('apple')
  end

  it 'returns a default value if no input is provided' do
    $stdin.expects(:tty?).returns(true)
    $stdin.expects(:gets).returns('')
    $stderr.expects(:print)

    is_expected.to run
      .with_params('Select a fruit', %w[apple banana carrot], 'default' => 'apple')
      .and_return('apple')
  end

  it 'errors if default value is not a valid option' do
    is_expected.to run
      .with_params('Select a fruit', %w[apple banana carrot], 'default' => 'durian')
      .and_raise_error(/Default value 'durian' is not one of the provided menu options/)
  end

  it 'reports the call to analytics' do
    executor.expects(:report_function_call).with('prompt::menu')
    executor.expects(:prompt).with("(1) apple\nSelect a fruit", {}).returns('1')
    is_expected.to run.with_params('Select a fruit', ['apple'])
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that prompt is not available' do
      is_expected.to run.with_params('Select a fruit', %w[apple banana carrot])
                        .and_raise_error(/Plan language function 'prompt::menu' cannot be used/)
    end
  end
end
