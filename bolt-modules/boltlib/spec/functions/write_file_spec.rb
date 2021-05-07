# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'write_file' do
  let(:executor) { Bolt::Executor.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'errors in noop mode' do
    executor.expects(:noop).returns(true)

    is_expected.to run
      .with_params('example.com', 'Hello, world!', 'hello.txt')
      .and_raise_error(Bolt::Error, /write_file is not supported in noop mode/)
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that write_file is not available' do
      is_expected.to run.with_params('example.com', 'Hello, world!', 'hello.txt')
                        .and_raise_error(/Plan language function 'write_file' cannot be used/)
    end
  end
end
