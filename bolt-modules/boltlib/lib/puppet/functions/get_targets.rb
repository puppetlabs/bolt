# frozen_string_literal: true

require 'bolt/error'

# Parses common ways of referring to targets and returns an array of Targets.
Puppet::Functions.create_function(:get_targets) do
  # @param names A pattern or array of patterns identifying a set of targets.
  # @return A list of unique Targets resolved from any target URIs and groups.
  # @example Resolve a group
  #   get_targets('group1')
  # @example Resolve a target URI
  #   get_targets('winrm://host2:54321')
  # @example Resolve array of groups and/or target URIs
  #   get_targets(['host1', 'group1', 'winrm://host2:54321'])
  # @example Resolve string consisting of a comma-separated list of groups and/or target URIs
  #   get_targets('host1,group1,winrm://host2:54321')
  # @example Run on localhost
  #   get_targets('localhost')
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
