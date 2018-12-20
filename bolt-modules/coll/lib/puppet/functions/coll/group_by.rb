# frozen_string_literal: true

# Groups the collection by result of the block. Returns a hash where the keys are the evaluated result from the block
# and the values are arrays of elements in the collection that correspond to the key.
Puppet::Functions.create_function(:'coll::group_by') do
  # @param collection A collection of things to group.
  # @example Group targets by protocol, results in e.g. { ssh => [target1, target2], winrm => [target3]}
  #   get_targets($nodes).group_by |$target| {
  #     $target.protocol
  #   }
  dispatch :group_by do
    required_param 'Iterable', :collection
    block_param
    return_type 'Hash'
  end

  def group_by(collection, &block)
    collection.group_by(&block).freeze
  end
end
