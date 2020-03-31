# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Get a single target from inventory if it exists, otherwise create a new Target.
#
# > **Note:** Calling `get_target('all')` returns an empty array.
Puppet::Functions.create_function(:get_target) do
  # @param name A Target name.
  # @return A single target, either new or from inventory.
  # @example Create a new Target from a URI
  #   get_target('winrm://host2:54321')
  # @example Get an existing Target from inventory
  #   get_target('existing-target')
  dispatch :get_target do
    param 'Boltlib::TargetSpec', :name
    return_type 'Target'
  end

  def get_target(name)
    inventory = Puppet.lookup(:bolt_inventory)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call(self.class.name)

    unless inventory.version > 1
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::UNSUPPORTED_INVENTORY_VERSION, action: 'get_target')
    end

    inventory.get_target(name)
  end
end
