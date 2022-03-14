# frozen_string_literal: true

# The `Target` object represents a target and its specific connection options.
#
# @param config
#   The inventory configuration for the target. This function returns the
#   configuration set directly on the target in `inventory.yaml` or set in
#   a plan using `Target.new` or `set_config()`. It does not return default
#   configuration values or configuration set in Bolt configuration files.
# @param facts
#   The target's facts. This function does not look up facts for a target and
#   only returns the facts specified in an `inventory.yaml` file or set on a
#   target during a plan run. To retrieve facts for a target and set them in
#   inventory, run the [facts](writing_plans.md#collect-facts-from-targets)
#   plan or [puppetdb_fact](writing_plans.md#collect-facts-from-puppetdb)
#   plan.
# @param features
#   The target's features.
# @param name
#   The target's human-readable name, or its URI if a name was not given.
# @param plugin_hooks
#   The target's `plugin_hooks` [configuration
#   options](bolt_inventory_reference.md#plugin-hooks-1).
# @param resources
#   The target's resources. This function does not look up resources for a
#   target and only returns resources set on a target during a plan run.
# @param safe_name
#   The target's safe name. Equivalent to `name` if a name was given, or the
#   target's `uri` with any password omitted.
# @param target_alias
#   The target's aliases.
# @param uri
#   The target's URI.
# @param vars
#   The target's variables.
#
# @!method host
#   The target's hostname.
# @!method password
#   The password to use when connecting to the target.
# @!method port
#   The target's connection port.
# @!method protocol
#   The protocol used to connect to the target. This is equivalent to the target's
#   `transport`, expect for targets using the `remote` transport. For example,
#   a target with the URI `http://example.com` using the `remote` transport would
#   return `http` for the `protocol`.
# @!method transport
#   The transport used to connect to the target.
# @!method transport_config
#   The merged configuration for the target's `transport`. This function returns
#   configuration that includes defaults set by Bolt, configuration set in
#   `inventory.yaml`, configuration set in `bolt-defaults.yaml`, and configuration
#   set in a plan using `set_config()`.
# @!method user
#   The user to connect to the target.
#
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
