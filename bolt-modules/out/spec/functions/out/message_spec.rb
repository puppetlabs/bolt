# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/target'

describe 'out::message' do
  let(:executor) { Bolt::Executor.new }
  let(:events) { [] }
  let(:outputter) { stub('outputter') }

  around(:each) do |example|
    executor.subscribe(outputter)

    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it "sends a message event to the executor" do
    outputter.expects(:handle_event).with(type: :message, message: 'hello world')
    is_expected.to run.with_params('hello world')
    executor.shutdown
  end
end
