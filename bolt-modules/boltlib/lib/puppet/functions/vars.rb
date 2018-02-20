require 'bolt/error'

# Returns a hash of the 'vars' (variables) assigned to a target through the
# inventory file or `set_var` function.
#
# Accepts no parameters.
#
# Plan authors can call this function on a target to get the variable hash
# for that target.
Puppet::Functions.create_function(:vars) do
  dispatch :vars do
    param 'Target', :target
    return_type 'Hash[String, Data]'
  end

  def vars(target)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'set_var'
      )
    end

    inventory = Puppet.lookup(:bolt_inventory) { nil }

    inventory.vars(target)
  end
end
