# frozen_string_literal: true

Puppet::DataTypes.create_type('ApplyResult') do
  interface <<-PUPPET
    attributes => {
      'report' => Hash[String[1], Data],
      'target' => Target
    },
    functions => {
      error => Callable[[], Optional[Error]],
      ok => Callable[[], Boolean],
      message => Callable[[], Optional[String]],
      action => Callable[[], String],
      to_data => Callable[[], Hash],
    }
  PUPPET

  load_file('bolt/apply_result')

  # Needed for Puppet to recognize Bolt::ApplyResult as a Puppet object when deserializing
  Bolt::ApplyResult.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ApplyResult
end
