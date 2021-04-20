# frozen_string_literal: true

# `ResourceInstance` objects are used to store the observed and desired state of a
# target's resource and to track events for the resource. These objects do not
# modify or interact with a target's resources.
#
# > The `ResourceInstance` data type is experimental and might change in a future
# > release. You can learn more about this data type and how to use it in the
# > [experimental features
# > documentation](experimental_features.md#resourceinstance-data-type).
#
# @param events
#   Events for the resource.
# @param desired_state
#   [Attributes](https://puppet.com/docs/puppet/latest/lang_resources.html#attributes) describing
#   the desired state of the resource.
# @param state
#   [Attributes](https://puppet.com/docs/puppet/latest/lang_resources.html#attributes) describing
#   the observed state of the resource.
# @param target
#   The resource's target.
# @param title
#   The [resource title](https://puppet.com/docs/puppet/latest/lang_resources.html#title).
# @param type
#   The [resource type](https://puppet.com/docs/puppet/latest/lang_resources.html#resource-types).
#
# @!method []
#   Accesses the `state` hash directly and returns the value for the specified
#   attribute. This function does not use dot noation. Call the function directly
#   on the `ResourceInstance`. For example, `$resource['ensure']`.
# @!method add_event(event)
#   Add an event for the resource.
# @!method overwrite_desired_state(desired_state)
#   Overwrites the desired state of the resource.
# @!method overwrite_state(state)
#   Overwrites the observed state of the resource.
# @!method set_desired_state(desired_state)
#   Sets attributes describing the desired state of the resource. Performs a shallow
#   merge with existing desired state.
# @!method set_state(state)
#   Sets attributes describing the observed state of the resource. Performs a shallow
#   merge with existing state.
# @!method reference
#   The resources reference string. For example, `File[/etc/puppetlabs]`.
#
Puppet::DataTypes.create_type('ResourceInstance') do
  interface <<-PUPPET
    attributes => {
      'target'        => Target,
      'type'          => Variant[String[1], Type[Resource]],
      'title'         => String[1],
      'state'         => Optional[Hash[String[1], Data]],
      'desired_state' => Optional[Hash[String[1], Data]],
      'events'        => Optional[Array[Hash[String[1], Data]]]
    },
    functions => {
      add_event               => Callable[[Hash[String[1], Data]], Array[Hash[String[1], Data]]],
      set_state               => Callable[[Hash[String[1], Data]], Hash[String[1], Data]],
      overwrite_state         => Callable[[Hash[String[1], Data]], Hash[String[1], Data]],
      set_desired_state       => Callable[[Hash[String[1], Data]], Hash[String[1], Data]],
      overwrite_desired_state => Callable[[Hash[String[1], Data]], Hash[String[1], Data]],
      reference               => Callable[[], String],
      '[]'                    => Callable[[String[1]], Data]
    }
  PUPPET

  load_file('bolt/resource_instance')
  # Needed for Puppet to recognize Bolt::ResourceInstance as a Puppet object when deserializing
  Bolt::ResourceInstance.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ResourceInstance
end
