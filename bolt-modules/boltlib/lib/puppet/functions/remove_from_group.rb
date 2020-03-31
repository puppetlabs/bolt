# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Removes a target from the specified inventory group.
#
# The target is removed from all child groups and all parent groups where the target has
# not been explicitly defined. A target cannot be removed from the `all` group.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:remove_from_group) do
  # @param target A pattern identifying a single target.
  # @param group The name of the group to remove the target from.
  # @example Remove Target from group.
  #   remove_from_group('foo@example.com', 'group1')
  # @example Remove failing Targets from the rest of a plan
  #   $result = run_command(uptime, my_group, '_catch_errors' => true)
  #   $result.error_set.targets.each |$t| { remove_from_group($t, my_group) }
  #   run_command(next_command, my_group) # does not target the failing nodes.
  dispatch :remove_from_group do
    param 'Boltlib::TargetSpec', :target
    param 'String[1]', :group
  end

  def remove_from_group(target, group)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: 'remove_from_group')
    end

    inventory = Puppet.lookup(:bolt_inventory)
    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    inventory.remove_from_group(inventory.get_targets(target), group)
  end
end
