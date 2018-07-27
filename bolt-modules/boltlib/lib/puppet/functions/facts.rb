# frozen_string_literal: true

require 'bolt/error'

# Returns the facts hash for a target.
Puppet::Functions.create_function(:facts) do
  # @param target A target.
  # @return The target's facts.
  # @example Getting facts
  #   facts($target)
  dispatch :facts do
    param 'Target', :target
    return_type 'Hash[String, Data]'
  end

  def facts(target)
    inventory = Puppet.lookup(:bolt_inventory) { nil }

    unless inventory
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('get facts for a target')
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call('facts')

    inventory.facts(target)
  end
end
