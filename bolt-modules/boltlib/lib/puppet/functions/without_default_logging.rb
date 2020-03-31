# frozen_string_literal: true

require 'bolt/pal/issues'

# Define a block where default logging is suppressed.
#
# Messages for actions within this block will be logged at `info` level instead
# of `notice`, so they will not be seen normally but will still be present
# when `verbose` logging is requested.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:without_default_logging) do
  # @param block The block where action logging is suppressed.
  # @return [Undef]
  # @example Suppress default logging for a series of functions
  #   without_default_logging() || {
  #     notice("Deploying on ${nodes}")
  #     get_targets($targets).each |$target| {
  #       run_task(deploy, $target)
  #     }
  #   }
  dispatch :without_default_logging do
    block_param 'Callable[0, 0]', :block
  end

  def without_default_logging
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: 'without_default_logging')
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    executor.without_default_logging do
      yield
    end
  end
end
