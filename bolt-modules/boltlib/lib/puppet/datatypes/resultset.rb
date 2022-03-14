# frozen_string_literal: true

# For each target that you execute an action on, Bolt returns a `Result` object
# and adds the `Result` to a `ResultSet` object. In the case of [apply
# actions](applying_manifest_blocks.md), Bolt returns a `ResultSet` with one or
# more `ApplyResult` objects.
#
# @param results
#   All results in the set.
#
# @!method []
#   The accessed results. This function does not use dot notation. Call the
#   function directly on the `ResultSet`. For example, `$results[0]`.
# @!method count
#   The number of results in the set.
# @!method empty
#   Whether the set is empty.
# @!method error_set
#   The set of failing results.
# @!method filter_set
#   Filters a set of results by the contents of the block.
# @!method find(target_name)
#   Retrieves a result for a specified target.
# @!method first
#   The first result in the set. Useful for unwrapping single results.
# @!method names
#   The names of all targets that have a `Result` in the set.
# @!method ok
#   Whether all results were successful. Equivalent to `$results.error_set.empty`.
# @!method ok_set
#   The set of successful results.
# @!method targets
#   The list of targets that have results in the set.
# @!method to_data
#   An array of serialized representations of each result in the set.
#
Puppet::DataTypes.create_type('ResultSet') do
  interface <<-PUPPET
    attributes => {
      'results' => Array[Variant[Result, ApplyResult]],
    },
    functions => {
      count => Callable[[], Integer],
      empty => Callable[[], Boolean],
      error_set => Callable[[], ResultSet],
      filter_set => Callable[[Callable], ResultSet],
      find => Callable[[String[1]], Optional[Variant[Result, ApplyResult]]],
      first => Callable[[], Optional[Variant[Result, ApplyResult]]],
      names => Callable[[], Array[String[1]]],
      ok => Callable[[], Boolean],
      ok_set => Callable[[], ResultSet],
      targets => Callable[[], Array[Target]],
      to_data => Callable[[], Array[Hash]],
      '[]' => Variant[Callable[[Integer], Optional[Variant[Result, ApplyResult, Array[Variant[Result, ApplyResult]]]]],
                      Callable[[Integer, Integer], Optional[Variant[Result, ApplyResult, Array[Variant[Result, ApplyResult]]]]]
                     ]
    }
  PUPPET

  load_file('bolt/result_set')

  # Needed for Puppet to recognize Bolt::ResultSet as a Puppet object when deserializing
  Bolt::ResultSet.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ResultSet
end
