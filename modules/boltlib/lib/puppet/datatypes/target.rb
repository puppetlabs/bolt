Puppet::DataTypes.create_type('Target') do
  interface <<-PUPPET
    attributes => {
      uri => String[1],
      options => { type => Hash[String[1], Data], value => {} }
    },
    functions => {
      host => Callable[[], String[1]],
      name => Callable[[], String[1]],
      password => Callable[[], Optional[String[1]]],
      port => Callable[[], Optional[Integer]],
      protocol => Callable[[], Optional[String[1]]],
      user => Callable[[], Optional[String[1]]],
    }
    PUPPET

  load_file('bolt/target')

  implementation_class Bolt::Target
end
