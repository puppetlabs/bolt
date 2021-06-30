# frozen_string_literal: true

# Log a debugging message.
#
# Messages logged at this level typically include detailed information about
# what a plan is doing. For example, you might log a message at the `debug`
# level that shows what value is returned from a function invocation.
#
# See [Logs](logs.md) for more information about Bolt's log levels.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'log::debug') do
  # Log a debugging message.
  # @param message The message to log.
  # @example Log a debugging message
  #   log::trace("Function frogsay returned: ${result}")
  dispatch :log_debug do
    param 'Any', :message
    return_type 'Undef'
  end

  def log_debug(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'log::debug'
      )
    end

    Puppet.lookup(:bolt_executor).tap do |executor|
      executor.report_function_call(self.class.name)
      executor.publish_event(type: :log, level: :debug, message: message)
    end

    nil
  end
end
