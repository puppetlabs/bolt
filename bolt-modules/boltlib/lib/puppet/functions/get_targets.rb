# frozen_string_literal: true

require 'bolt/error'

# Parses common ways of referring to targets and returns an array of Targets.
# `get_targets('all')` returns an empty array.
#
# > **Note:** Not available in apply block when `future` is true
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
    inventory = Puppet.lookup(:bolt_inventory)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call(self.class.name)

    inventory.get_targets(names)
  end
end
