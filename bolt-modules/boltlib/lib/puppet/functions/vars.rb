# frozen_string_literal: true

require 'bolt/error'

# Returns a hash of the 'vars' (variables) assigned to a target.
#
# Vars can be assigned through the inventory file or `set_var` function.
# Plan authors can call this function on a target to get the variable hash
# for that target.
Puppet::Functions.create_function(:vars) do
  # @param target The Target object to get variables from. See {get_targets}.
  # @return A hash of the 'vars' (variables) assigned to a target.
  # @example Get vars for a target
  #   $target.vars
  dispatch :vars do
    param 'Target', :target
    return_type 'Hash[String, Data]'
  end

  def vars(target)
    inventory = Puppet.lookup(:bolt_inventory)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call(self.class.name)

    inventory.vars(target)
  end
end
