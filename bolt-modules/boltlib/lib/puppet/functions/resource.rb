# frozen_string_literal: true

# Lookup a resource in the target's data.
#
# For more information about resources see [the
# documentation](https://puppet.com/docs/puppet/latest/lang_resources.html).
#
# > **Note:** The `ResourceInstance` data type is under active development and is subject to
#   change. You can read more about the data type in the [experimental features
#   documentation](experimental_features.md#resourceinstance-data-type).
Puppet::Functions.create_function(:resource) do
  # Lookup a resource in the target's data.
  # @param target The Target object to add resources to. See {get_targets}.
  # @param type The type of the resource
  # @param title The title of the resource
  # @return The ResourceInstance if found, or Undef
  # @example Get the openssl package resource
  #   $target.apply_prep
  #   $resources = $target.get_resources(Package).first['resources']
  #   $target.set_resources($resources)
  #   $openssl = $target.resource('Package', 'openssl')
  dispatch :resource do
    param 'Target', :target
    param 'Type[Resource]', :type
    param 'String[1]', :title
    return_type 'Optional[ResourceInstance]'
  end

  # Lookup a resource in the target's data, referring to resource as a string
  # @param target The Target object to add resources to. See {get_targets}.
  # @param type The type of the resource
  # @param title The title of the resource
  # @return The ResourceInstance if found, or Undef
  dispatch :resource_from_string do
    param 'Target', :target
    param 'String[1]', :type
    param 'String[1]', :title
    return_type 'Optional[ResourceInstance]'
  end

  def resource(target, type, title)
    inventory = Puppet.lookup(:bolt_inventory)
    executor  = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call(self.class.name)

    inventory.resource(target, type, title)
  end

  def resource_from_string(target, type, title)
    resource(target, type, title)
  end
end
