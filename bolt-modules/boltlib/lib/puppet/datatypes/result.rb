# frozen_string_literal: true

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
