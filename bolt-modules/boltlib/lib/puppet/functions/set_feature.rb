# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Sets a particular feature to present on a target.
#
# Features are used to determine what implementation of a task should be run.
# Supported features are:
# - `powershell`
# - `shell`
# - `puppet-agent`
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:set_feature) do
  # @param target The Target object to add features to. See {get_targets}.
  # @param feature The string identifying the feature.
  # @param value Whether the feature is supported.
  # @return The target with the updated feature
  # @example Add the `puppet-agent` feature to a target
  #   set_feature($target, 'puppet-agent', true)
  dispatch :set_feature do
    param 'Target', :target
    param 'String', :feature
    optional_param 'Boolean', :value
    return_type 'Target'
  end

  def set_feature(target, feature, value = true)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'set_feature')
    end

    inventory = Puppet.lookup(:bolt_inventory)
    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    inventory.set_feature(target, feature, value)

    target
  end
end
