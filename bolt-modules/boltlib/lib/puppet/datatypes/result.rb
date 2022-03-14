# frozen_string_literal: true

# For each target that you execute an action on, Bolt returns a `Result` object
# and adds the `Result` to a `ResultSet` object. A `Result` object contains
# information about the action you executed on the target.
#
# @param target
#   The target the result is from.
# @param value
#   The output or return of executing on the target.
#
# @!method []
#   Accesses the `value` hash directly and returns the value for the key. This
#   function does not use dot nation. Call the function directly on the `Result`.
#   For example, `$result['key']`.
# @!method action
#   The type of result. For example, `task` or `command`.
# @!method error
#   An object constructed from the `_error` field of the result's `value`.
# @!method message
#   The `_output` field of the result's value.
# @!method ok
#   Whether the result was successful.
# @!method sensitive
#   The `_sensitive` field of the result's value, wrapped in a `Sensitive` object.
#   Call `unwrap()` to extract the value.
# @!method status
#   Either `success` if the result was successful or `failure`.
# @!method to_data
#   A serialized representation of `Result`.
#
Puppet::DataTypes.create_type('Result') do
  interface <<-PUPPET
    attributes => {
      'value' => Hash[String[1], Data],
      'target' => Target
    },
    functions => {
      error => Callable[[], Optional[Error]],
      message => Callable[[], Optional[String]],
      sensitive => Callable[[], Optional[Sensitive[Data]]],
      action => Callable[[], String],
      status => Callable[[], String],
      to_data => Callable[[], Hash],
      ok => Callable[[], Boolean],
      '[]' => Callable[[String[1]], Variant[Data, Sensitive[Data]]]
    }
  PUPPET

  load_file('bolt/result')

  # Needed for Puppet to recognize Bolt::Result as a Puppet object when deserializing
  Bolt::Result.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::Result
end
