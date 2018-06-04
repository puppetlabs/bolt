# frozen_string_literal: true

require 'spec_helper'

describe 'facts::group_by' do
  it 'delegates to the native group_by function' do
    collection = mock('Puppet::Pops::Types::Iterable').extend(Puppet::Pops::Types::Iterable)
    return_value = {}

    verifier = mock('verifier')
    token = mock('token')

    collection.expects(:group_by).with.yields(token).returns(return_value)
    # this is to verify that the block passed to the 'facts::group_by' function
    # is yielded to from the stubbed group_by method
    verifier.expects(:verify).with(token)

    is_expected.to run.with_params(collection).with_lambda(&(proc do |t|
      verifier.verify(t)
    end)).and_return(return_value)
  end
end
