# frozen_string_literal: true

module Bolt
  class PAL
    module Issues
      # Create issue using Issues api
      PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING =
        Puppet::Pops::Issues.issue :PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, :action do
          "Plan language function '#{action}' cannot be used from declarative manifest code or apply blocks"
        end

      # Inventory version 2
      UNSUPPORTED_INVENTORY_VERSION =
        Puppet::Pops::Issues.issue :UNSUPPORTED_INVENTORY_VERSION, :action do
          "Plan language function '#{action}' cannot be used with Inventory v1"
        end
    end
  end
end
