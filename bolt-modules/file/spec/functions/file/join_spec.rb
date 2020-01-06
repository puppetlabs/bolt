# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'

describe 'file::join' do
  let(:executor) { Bolt::Executor.new }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor) { example.run }
  end

  it 'joins file paths' do
    is_expected.to run.with_params('foo', 'bar', 'bak').and_return('foo/bar/bak')
  end

  it 'reports function call to analytics' do
    executor.expects(:report_function_call).with('file::join')
    is_expected.to run.with_params('foo', 'bar', 'bak')
  end
end
