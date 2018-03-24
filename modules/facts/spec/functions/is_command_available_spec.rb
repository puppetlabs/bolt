# frozen_string_literal: true

require 'spec_helper'

describe 'facts::is_command_available' do
  let(:command) { 'command' }

  it 'returns true if the specified command is available' do
    Puppet::Util.expects(:which).with(command).returns('/path/to/command')

    is_expected.to run.with_params(command).and_return(true)
  end

  it 'returns false if the specified command is not available' do
    Puppet::Util.expects(:which).with(command).returns(nil)

    is_expected.to run.with_params(command).and_return(false)
  end
end
