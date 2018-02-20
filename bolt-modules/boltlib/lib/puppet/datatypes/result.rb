Puppet::DataTypes.create_type('Result') do
  interface <<-PUPPET
    attributes => {
      'value' => Hash[String[1], Data],
      'target' => Target
    },
    functions => {
      error => Callable[[], Optional[Error]],
      message => Callable[[], Optional[String]],
      ok => Callable[[], Boolean],
      '[]' => Callable[[String[1]], Data]
    }
  PUPPET

  load_file('bolt/result')

  implementation_class Bolt::Result
end
