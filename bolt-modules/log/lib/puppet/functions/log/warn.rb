# frozen_string_literal: true

require 'bolt/util/format'

# Log a warning message.
#
# Messages logged at this level typically include messages about deprecated
# behavior or potentially harmful situations that might affect the plan run.
# For example, you might log a message at the `warn` level if you are
# planning to make a breaking change to your plan in a future release and
# want to notify users.
#
# See [Logs](logs.md) for more information about Bolt's log levels.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'log::warn') do
  # Log a warning message.
  # @param message The message to log.
  # @example Log a warning message
  #   log::warn('This plan will no longer install the package in a future release.')
  dispatch :log_warn do
    param 'Any', :message
    return_type 'Undef'
  end

  def log_warn(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'log::warn'
      )
    end

    Puppet.lookup(:bolt_executor).tap do |executor|
      executor.report_function_call(self.class.name)
      executor.publish_event(type: :log, level: :warn, message: Bolt::Util::Format.stringify(message))
    end

    nil
  end
end
