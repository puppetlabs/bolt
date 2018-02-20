Puppet::DataTypes.create_type('ResultSet') do
  interface <<-PUPPET
    attributes => {
      'results' => Array[Result],
    },
    functions => {
      count => Callable[[], Integer],
      empty => Callable[[], Boolean],
      error_set => Callable[[], ResultSet],
      find => Callable[[String[1]], Optional[Result]],
      first => Callable[[], Optional[Result]],
      names => Callable[[], Array[String[1]]],
      ok => Callable[[], Boolean],
      ok_set => Callable[[], ResultSet],
      targets => Callable[[], Array[Target]],
    }
  PUPPET

  load_file('bolt/result_set')

  implementation_class Bolt::ResultSet
end
