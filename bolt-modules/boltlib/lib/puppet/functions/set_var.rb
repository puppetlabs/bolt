# frozen_string_literal: true

require 'bolt/error'

# Sets a variable { key => value } for a target.
#
# This function takes 3 parameters:
# * A Target object to set the variable for
# * The key for the variable (String)
# * The value of the variable (Data)
#
# Returns undef.
Puppet::Functions.create_function(:set_var) do
  dispatch :set_var do
    param 'Target', :target
    param 'String', :key
    param 'Data', :value
  end

  def set_var(target, key, value)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'set_var'
      )
    end

    inventory = Puppet.lookup(:bolt_inventory) { nil }

    unless inventory
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('set a var on a target')
      )
    end

    inventory.set_var(target, key, value)
  end
end
