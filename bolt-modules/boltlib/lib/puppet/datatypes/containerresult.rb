# frozen_string_literal: true

# The [run_container](plan_functions.md#run_container) plan function returns a
# `ContainerResult` object. A `ContainerResult` is a standalone object (not part
# of a `ResultSet`) that includes either the `stdout` and `stderr` values from
# running the container, or an `_error` object if the container exited with a
# nonzero exit code.
#
# @param value
#   A hash including the `stdout`, `stderr`, and `exit_code` received from the
#   container.
#
# @!method []
#   Accesses the value hash directly and returns the value for the key. This
#   function does not use dot notation. Call the function directly on the
#   `ContainerResult`. For example, `$result[key]`.
# @!method error
#   An object constructed from the `_error` field of the result's value.
# @!method ok
#   Whether the result was successful.
# @!method status
#   Either `success` if the result was successful or `failure`.
# @!method stdout
#   The value of 'stdout' output by the container.
# @!method stderr
#   The value of 'stderr' output by the container.
# @!method to_data
#   A serialized representation of `ContainerResult`.
#
Puppet::DataTypes.create_type('ContainerResult') do
  interface <<-PUPPET
    attributes => {
      'value' => Hash[String[1], Data],
    },
    functions => {
      '[]' => Callable[[String[1]], Data],
      error => Callable[[], Optional[Error]],
      ok => Callable[[], Boolean],
      status => Callable[[], String],
      stdout => Callable[[], String],
      stderr => Callable[[], String],
      to_data => Callable[[], Hash]
    }
  PUPPET

  load_file('bolt/container_result')

  # Needed for Puppet to recognize Bolt::ContainerResult as a Puppet object when deserializing
  Bolt::ContainerResult.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ContainerResult
end
