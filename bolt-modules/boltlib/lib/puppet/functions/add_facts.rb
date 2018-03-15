# frozen_string_literal: true

require 'bolt/error'

# Deep merges a hash of facts with the existing facts has on a target.

Puppet::Functions.create_function(:add_facts) do
  dispatch :add_facts do
    param 'Target', :target
    param 'Hash', :facts
  end

  def add_facts(target, facts)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'add_facts'
      )
    end

    inventory = Puppet.lookup(:bolt_inventory) { nil }

    unless inventory
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('add facts')
      )
    end

    inventory.add_facts(target, facts)
  end
end
