# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Sets a variable `{ key => value }` for a target.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:set_var) do
  # @param target The Target object to set the variable for. See {get_targets}.
  # @param key The key for the variable.
  # @param value The value of the variable.
  # @return The target with the updated feature
  # @example Set a variable on a target
  #   $target.set_var('ephemeral', true)
  dispatch :set_var do
    param 'Target', :target
    param 'String', :key
    param 'Data', :value
    return_type 'Target'
  end

  def set_var(target, key, value)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'set_var')
    end

    inventory = Puppet.lookup(:bolt_inventory)
    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    var_hash = { key => value }
    inventory.set_var(target, var_hash)

    target
  end
end
