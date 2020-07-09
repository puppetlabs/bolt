# frozen_string_literal: true

# This was failing local test runs
require 'bolt/target'

Puppet::DataTypes.create_type('Target') do
  begin
    inventory = Puppet.lookup(:bolt_inventory)
    target_implementation_class = inventory.target_implementation_class
  rescue Puppet::Context::UndefinedBindingError
    target_implementation_class = Bolt::Target
  end

  interface <<-PUPPET
    attributes => {
      uri => { type => Optional[String[1]], kind => given_or_derived },
      name => { type => Optional[String[1]] , kind => given_or_derived },
      safe_name => { type =>  Optional[String[1]], kind => given_or_derived },
      target_alias => { type => Optional[Variant[String[1], Array[String[1]]]], kind => given_or_derived },
      config => { type => Optional[Hash[String[1], Data]], kind => given_or_derived },
      vars => { type => Optional[Hash[String[1], Data]], kind => given_or_derived },
      facts => { type => Optional[Hash[String[1], Data]], kind => given_or_derived },
      features => { type => Optional[Array[String[1]]], kind => given_or_derived },
      plugin_hooks => { type => Optional[Hash[String[1], Data]], kind => given_or_derived },
      resources => { type => Optional[Hash[String[1], ResourceInstance]], kind => given_or_derived }
    },
    functions => {
      host => Callable[[], Optional[String]],
      password => Callable[[], Optional[String[1]]],
      port => Callable[[], Optional[Integer]],
      protocol => Callable[[], Optional[String[1]]],
      transport => Callable[[], String[1]],
      transport_config => Callable[[], Hash[String[1], Data]],
      user => Callable[[], Optional[String[1]]]
    }
  PUPPET

  # Needed for Puppet to recognize targets as Puppet objects when deserializing
  target_implementation_class.include(Puppet::Pops::Types::PuppetObject)
  implementation_class target_implementation_class
end
