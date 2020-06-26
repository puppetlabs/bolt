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
    inventory = Puppet.lookup(:bolt_inventory)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    # Send Analytics Report
    executor&.report_function_call(self.class.name)

    inventory.facts(target)
  end
end
