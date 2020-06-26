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
  # Set a single resource from a data hash.
  # @param target The `Target` object to add a resource to. See {get_targets}.
  # @param resource The resource data hash used to set a resource on the target.
  # @return An array with the added `ResourceInstance` object.
  # @example Add a resource to a target from a data hash.
  #   $resource_hash = {
  #     'type'  => File,
  #     'title' => '/etc/puppetlabs',
  #     'state' => { 'ensure' => 'present' }
  #   }
  #
  #   $target.set_resources($resource_hash)
  dispatch :set_single_resource_from_hash do
    param 'Target', :target
    param 'Hash', :resource
    return_type 'Array[ResourceInstance]'
  end

  # Set a single resource from a `ResourceInstance` object
  # @param target The `Target` object to add a resource to. See {get_targets}.
  # @param resource The `ResourceInstance` object to set on the target.
  # @return An array with the added `ResourceInstance` object.
  # @example Add a resource to a target from a `ResourceInstance` object.
  #   $resource_instance = ResourceInstance.new(
  #     'target' => $target,
  #     'type'   => File,
  #     'title'  => '/etc/puppetlabs',
  #     'state'  => { 'ensure' => 'present' }
  #   )
  #
  #   $target.set_resources($resource_instance)
  dispatch :set_single_resource_from_object do
    param 'Target', :target
    param 'ResourceInstance', :resource
    return_type 'Array[ResourceInstance]'
  end

  # Set multiple resources from an array of data hashes and `ResourceInstance` objects.
  # @param target The `Target` object to add resources to. See {get_targets}.
  # @param resources The resource data hashes and `ResourceInstance` objects to set on the target.
  # @return An array of the added `ResourceInstance` objects.
  # @example Add resources from resource data hashes returned from an apply block.
  #   $apply_results = apply($targets) {
  #     File { '/etc/puppetlabs':
  #       ensure => present
  #     }
  #     Package { 'openssl':
  #       ensure => installed
  #     }
  #   }
  #
  #   $apply_results.each |$result| {
  #     $result.target.set_resources($result.report['resource_statuses'].values)
  #   }
  # @example Add resources retrieved with [`get_resources`](#get_resources) to a target.
  #   $resources = $target.get_resources(Package).first['resources']
  #   $target.set_resources($resources)
  dispatch :set_resources do
    param 'Target', :target
    param 'Array[Variant[Hash, ResourceInstance]]', :resources
    return_type 'Array[ResourceInstance]'
  end

  def set_single_resource_from_hash(target, resource)
    set_resources(target, [resource])
  end

  def set_single_resource_from_object(target, resource)
    set_resources(target, [resource])
  end

  def set_resources(target, resources)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(
          Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
          action: 'set_resources'
        )
    end

    # Send Analytics Report
    Puppet.lookup(:bolt_executor).report_function_call(self.class.name)
    inventory = Puppet.lookup(:bolt_inventory)

    resources.uniq.map do |resource|
      if resource.is_a?(Hash)
        # ResourceInstance expects a Target object, so either get a specified target from
        # the inventory or use the target this function was called on.
        resource_target = if resource.key?('target')
                            inventory.get_target(resource['target'])
                          else
                            target
                          end

        # Observed state from get_resources() is under the 'parameters' key
        resource_state = resource['state'] || resource['parameters']

        # Type from apply results is under the 'resource_type' key
        resource_type = resource['type'] || resource['resource_type']

        init_hash = {
          'target'        => resource_target,
          'type'          => resource_type,
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

      unless resource.target == target
        file, line = Puppet::Pops::PuppetStack.top_of_stack
        raise Bolt::ValidationError, "Cannot set resource #{resource.reference} for target "\
                                     "#{resource.target} on target #{target}. "\
                                     "#{Puppet::Util::Errors.error_location(file, line)}"
      end

      target.set_resource(resource)
    end
  end
end
