Puppet::DataTypes.create_type('Target') do
  interface <<-PUPPET
    attributes => {
      host => String[1],
      options => { type => Hash[String[1], Data], value => {} }
    }
    PUPPET

  implementation_class Bolt::Target
end
