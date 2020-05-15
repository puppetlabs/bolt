# frozen_string_literal: true

require 'bolt/error'

# Sets one or more ResourceInstances on a Target. This function does not apply or modify
# resources on a target.
#
# For more information about resources see [the
# documentation](https://puppet.com/docs/puppet/latest/lang_resources.html).
#
# > **Note:** The `ResourceInstance` data type is under active development and is subject to
#   change. You can read more about the data type in the [experimental features
#   documentation](experimental_features.md#resourceinstance-data-type).
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:set_resources) do
  # Set multiple resources
  # @param target The `Target` object to add resources to. See {get_targets}.
  # @param resources The resources to set on the target.
  # @return The added `ResourceInstance` objects.
  # @example Add multiple resources to a target with an array of `ResourceInstance` objects.
  #   $resource1 = ResourceInstance.new(
  #     'target' => $target,
  #     'type'   => 'file',
  #     'title'  => '/etc/puppetlabs',
  #     'state'  => { 'ensure' => 'present' }
  #   )
  #   $resource2 = ResourceInstance.new(
  #     'target' => $target,
  #     'type'   => 'package',
  #     'title'  => 'openssl',
  #     'state'  => { 'ensure' => 'installed' }
  #   )
  #   $target.set_resources([$resource1, $resource2])
  # @example Add resources retrieved with [`get_resources`](#get_resources) to a target.
  #   $target.apply_prep
  #   $resources = $target.get_resources(Package).first['resources']
  #   $target.set_resources($resources)
  dispatch :set_resources do
    param 'Target', :target
    param 'Array[Variant[Hash, ResourceInstance]]', :resources
    return_type 'Array[ResourceInstance]'
  end

  # Set a single resource
  # @param target The `Target` object to add resources to. See {get_targets}.
  # @param resource The resource to set on the target.
  # @return The added `ResourceInstance` object.
  # @example Add a single resource to a target with a resource data hash.
  #   $resource = {
  #     'type'  => 'file',
  #     'title' => '/etc/puppetlabs',
  #     'state' => { 'ensure' => 'present' }
  #   }
  #   $target.set_resources($resource)
  dispatch :set_resource do
    param 'Target', :target
    param 'Variant[Hash, ResourceInstance]', :resource
    return_type 'Array[ResourceInstance]'
  end

  def set_resources(target, resources)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(
          Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
          action: 'set_resources'
        )
    end

    inventory = Puppet.lookup(:bolt_inventory)
    executor  = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    inventory_target = inventory.get_target(target)

    resources.uniq.map do |resource|
      if resource.is_a?(Hash)
        # ResourceInstance expects a Target object, so either get a specified target from
        # the inventory or use the target this function was called on.
        resource_target = if resource.key?('target')
                            inventory.get_target(resource['target'])
                          else
                            inventory_target
                          end

        # Observed state from get_resources() is under the 'parameters' key
        resource_state = resource['state'] || resource['parameters']

        init_hash = {
          'target'        => resource_target,
          'type'          => resource['type'],
          'title'         => resource['title'],
          'state'         => resource_state,
          'desired_state' => resource['desired_state'],
          'events'        => resource['events']
        }

        # Calling Bolt::ResourceInstance.new or Bolt::ResourceInstance.from_asserted_hash
        # will not perform any validation on the parameters. Instead, we need to use the
        # Puppet constructor to initialize the object, which will first validate the parameters
        # and then call Bolt::ResourceInstance.from_asserted_hash internally. To do this we
        # first need to get the Puppet datatype and then call the new function on that type.
        type = Puppet::Pops::Types::TypeParser.singleton.parse('ResourceInstance')
        resource = call_function('new', type, init_hash)
      end

      unless resource.target == inventory_target
        file, line = Puppet::Pops::PuppetStack.top_of_stack
        raise Bolt::ValidationError, "Cannot set resource #{resource.reference} for target "\
                                     "#{resource.target} on target #{inventory_target}. "\
                                     "#{Puppet::Util::Errors.error_location(file, line)}"
      end

      inventory_target.set_resource(resource)
    end
  end

  def set_resource(target, resource)
    set_resources(target, [resource])
  end
end
