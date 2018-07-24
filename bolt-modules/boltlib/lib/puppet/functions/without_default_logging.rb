# frozen_string_literal: true

# Define a block where default logging is suppressed.
#
# Messages for actions within this block will be logged at `info` level instead
# of `notice`, so they will not be seen normally but # will still be present
# when `verbose` logging is requested.
Puppet::Functions.create_function(:without_default_logging) do
  # @param block The block where action logging is suppressed.
  # @return [Undef]
  # @example Suppress default logging for a series of functions
  #   without_default_logging() || {
  #     notice("Deploying on ${nodes}")
  #     get_targets($nodes).each |$node| {
  #       run_task(deploy, $node)
  #     }
  #   }
  dispatch :without_default_logging do
    block_param 'Callable[0, 0]', :block
  end

  def without_default_logging
    executor = Puppet.lookup(:bolt_executor) { nil }
    executor.report_function_call('without_default_logging')

    old_log = executor.plan_logging
    executor.plan_logging = false
    begin
      yield
    ensure
      executor.plan_logging = old_log
    end
  end
end
