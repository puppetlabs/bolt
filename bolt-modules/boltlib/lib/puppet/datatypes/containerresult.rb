# frozen_string_literal: true

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
