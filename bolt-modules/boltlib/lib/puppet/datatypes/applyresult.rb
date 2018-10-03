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
    }
  PUPPET

  load_file('bolt/apply_result')

  implementation_class Bolt::ApplyResult
end
