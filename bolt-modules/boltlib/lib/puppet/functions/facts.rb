# frozen_string_literal: true

require 'bolt/error'

# Returns the facts hash for a target.
# This functions takes one parameter, the target to get facts for
Puppet::Functions.create_function(:facts) do
  dispatch :facts do
    param 'Target', :target
    return_type 'Hash[String, Data]'
  end

  def facts(target)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'facts'
      )
    end

    inventory = Puppet.lookup(:bolt_inventory) { nil }

    unless inventory
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('get facts for a target')
      )
    end

    inventory.facts(target)
  end
end
