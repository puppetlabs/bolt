# frozen_string_literal: true

module Bolt
  class PAL
    module Issues
      # Create issue using Issues api
      PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING =
        Puppet::Pops::Issues.issue :PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, :action do
          "Plan language function '#{action}' cannot be used from declarative manifest code or apply blocks"
        end
    end
  end
end
