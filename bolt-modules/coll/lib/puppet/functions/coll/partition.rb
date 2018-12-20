# frozen_string_literal: true

# Returns two arrays, the first containing the elements of enum for which the block evaluates to true,
# the second containing the rest.
Puppet::Functions.create_function(:'coll::partition') do
  # @param collection A collection of things to partition.
  # @example Partition targets by binary fact, results in e.g. { win => [target1, target2], not => [target3]}
  #   get_targets($nodes).partition |$target| {
  #     $target.fact['osfamily'] == 'windows'
  #   }
  dispatch :partition do
    required_param 'Iterable', :collection
    block_param
    return_type 'Tuple[Array, Array]'
  end

  def partition(collection, &block)
    collection.partition(&block).freeze
  end
end
