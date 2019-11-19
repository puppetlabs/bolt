# frozen_string_literal: true

Puppet::DataTypes.create_type('ApplyTarget') do
  load_file('bolt/apply_target')
  interface <<-PUPPET
    attributes => {
      'target_hash' => Hash
    },
    functions => {
      uri => Callable[[], String[1]],
      name => Callable[[], String[1]],
      target_alias => Callable[[], Optional[String]],
      config => Callable[[], Optional[Hash[String[1], Data]]],
      vars => Callable[[], Optional[Hash[String[1], Data]]],
      facts => Callable[[], Optional[Hash[String[1], Data]]],
      features => Callable[[], Optional[Array[String[1]]]],
      plugin_hooks => Callable[[], Optional[Hash[String[1], Data]]],
      safe_name => Callable[[], String[1]],
      host => Callable[[], Optional[String]],
      password => Callable[[], Optional[String[1]]],
      port => Callable[[], Optional[Integer]],
      protocol => Callable[[], Optional[String[1]]],
      user => Callable[[], Optional[String[1]]],
    }
  PUPPET

  implementation_class Bolt::ApplyTarget
end
