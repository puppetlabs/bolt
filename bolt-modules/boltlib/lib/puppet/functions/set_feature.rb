# frozen_string_literal: true

require 'bolt/error'

# Sets a particular feature to present on a target.
#
# Features are used to determine what implementation of a task should be run.
# Currently supported features are
# - powershell
# - shell
# - puppet-agent
Puppet::Functions.create_function(:set_feature) do
  # @param target The Target object to add features to. See {get_targets}.
  # @param feature The string identifying the feature.
  # @param value Whether the feature is supported.
  # @return [Undef]
  # @example Add the puppet-agent feature to a target
  #   set_feature($target, 'puppet-agent', true)
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

    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call('set_feature')

    inventory.set_feature(target, feature, value)

    target
  end
end
