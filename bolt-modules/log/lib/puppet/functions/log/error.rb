# frozen_string_literal: true

require 'bolt/util/format'

# Log an error message.
#
# Messages logged at this level typically indicate that the plan encountered an
# error that can be recovered from. For example, you might log a message at the
# `error` level if you want to inform the user an action running on a target
# failed but that the plan will continue running.
#
# See [Logs](logs.md) for more information about Bolt's log levels.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'log::error') do
  # Log an error message.
  # @param message The message to log.
  # @example Log an error message
  #   log::error("The HTTP request returned an error, continuing the plan: ${result}")
  dispatch :log_error do
    param 'Any', :message
    return_type 'Undef'
  end

  def log_error(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'log::error'
      )
    end

    Puppet.lookup(:bolt_executor).tap do |executor|
      executor.report_function_call(self.class.name)
      executor.publish_event(type: :log, level: :error, message: Bolt::Util::Format.stringify(message))
    end

    nil
  end
end
