# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans/mock_executor'
require 'bolt/executor'

describe BoltSpec::Plans::MockExecutor do
  it 'defines all public methods on Bolt::Executor' do
    missing_methods = Bolt::Executor.instance_methods - described_class.instance_methods
    message = "#{described_class} is missing definitions for public methods #{missing_methods.join(', ')}"

    expect(missing_methods.empty?).to be(true), message
  end
end
