# frozen_string_literal: true

require 'bolt/error'

# Sets a particular feature to present on a target.

Puppet::Functions.create_function(:set_feature) do
  dispatch :set_feature do
    param 'Target', :target
    param 'String', :feature
    optional_param 'Boolean', :value
  end

  def set_feature(target, feature, value = true)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'set_feature'
      )
    end

    inventory = Puppet.lookup(:bolt_inventory) { nil }

    unless inventory
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('set feature')
      )
    end

    inventory.set_feature(target, feature, value)

    target
  end
end
