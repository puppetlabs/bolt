# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Set configuration options on a target.
#
# > **Note:** Not available in apply block
#
# > **Note:** Only compatible with inventory v2
Puppet::Functions.create_function(:set_config) do
  # @param target The Target object to configure. See {get_targets}.
  # @param key_or_key_path The configuration setting to update.
  # @param value The configuration value
  # @return The Target with the updated config
  # @example Set the transport for a target
  #   set_config($target, 'transport', 'ssh')
  # @example Set the ssh password
  #   set_config($target, ['ssh', 'password'], 'secret')
  # @example Overwrite ssh config
  #   set_config($target, 'ssh', { user => 'me', password => 'secret' })
  dispatch :set_config do
    param 'Target', :target
    param 'Variant[String, Array[String]]', :key_or_key_path
    param 'Any', :value
    return_type 'Target'
  end

  def set_config(target, key_or_key_path, value = true)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'set_config')
    end

    inventory = Puppet.lookup(:bolt_inventory)
    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    unless inventory.version > 1
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::UNSUPPORTED_INVENTORY_VERSION, action: 'set_config')
    end

    inventory.set_config(target, key_or_key_path, value)

    target
  end
end
