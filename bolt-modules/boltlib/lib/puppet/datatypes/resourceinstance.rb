# frozen_string_literal: true

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
      reference               => Callable[[], String]
    }
  PUPPET

  load_file('bolt/resource_instance')
  # Needed for Puppet to recognize Bolt::ResourceInstance as a Puppet object when deserializing
  Bolt::ResourceInstance.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ResourceInstance
end
