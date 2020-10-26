# frozen_string_literal: true

require 'bolt/error'

# Returns the facts hash for a target.
#
# Using the `facts` function does not automatically collect facts for a target,
# and will only return facts that are currently set in the inventory. To collect
# facts from a target and set them in the inventory, run the
# [facts](writing_plans.md#collect-facts-from-targets) plan or
# [puppetdb_fact](writing_plans.md#collect-facts-from-puppetdb) plan.
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
    inventory = Puppet.lookup(:bolt_inventory)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    # Send Analytics Report
    executor&.report_function_call(self.class.name)

    inventory.facts(target)
  end
end
