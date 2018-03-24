# frozen_string_literal: true

# A simple wrapper of the ruby's group_by function.
Puppet::Functions.create_function(:'facts::group_by') do
  dispatch :native_group_by do
    param 'Iterable', :collection
    block_param
    return_type 'Hash'
  end

  def native_group_by(collection, &block)
    collection.group_by(&block)
  end
end
