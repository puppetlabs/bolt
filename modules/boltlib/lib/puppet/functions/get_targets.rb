# Parses common ways of referring to targets and returns an array of Targets.
#
# Accepts input consisting of
# - a group
# - a target URI
# - an array of groups and/or target URIs
# - a string that consists of a comma-separated list of groups and/or target URIs
#
# Examples of the above would be
# - 'group1'
# - 'host1,group1,winrm://host2:54321'
# - ['host1', 'group1', 'winrm://host2:54321']
#
# Returns an array of unique Targets resolved from any target URIs and groups.

require 'bolt/error'

Puppet::Functions.create_function(:get_targets) do
  dispatch :get_targets do
    param 'Boltlib::TargetSpec', :names
    return_type 'Array[Target]'
  end

  def get_targets(names)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'get_targets'
      )
    end

    inventory = Puppet.lookup(:bolt_inventory) { nil }

    unless inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('process targets through inventory')
      )
    end

    inventory.get_targets(names)
  end
end
