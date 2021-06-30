# frozen_string_literal: true

# Log a fatal message.
#
# Messages logged at this level indicate that the plan encountered an error that
# could not be recovered from. For example, you might log a message at the
# `fatal` level if a service is unavailable and the plan cannot continue running
# without it.
#
# See [Logs](logs.md) for more information about Bolt's log levels.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'log::fatal') do
  # Log a fatal message.
  # @param message The message to log.
  # @example Log a fatal message
  #   log::fatal("The service is unavailable, unable to continue running: ${result}")
  dispatch :log_fatal do
    param 'Any', :message
    return_type 'Undef'
  end

  def log_fatal(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'log::fatal'
      )
    end

    Puppet.lookup(:bolt_executor).tap do |executor|
      executor.report_function_call(self.class.name)
      executor.publish_event(type: :log, level: :fatal, message: message)
    end

    nil
  end
end
