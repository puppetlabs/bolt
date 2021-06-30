# frozen_string_literal: true

# Log a trace message.
#
# Messages logged at this level typically include the most detailed information
# about what a plan is doing. For example, you might log a message at the `trace`
# level that describes how a plan is manipulating data.
#
# See [Logs](logs.md) for more information about Bolt's log levels.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'log::trace') do
  # Log a trace message.
  # @param message The message to log.
  # @example Log a trace message
  #   log::trace("Creating Target object with data ${data} from file ${file}")
  dispatch :log_trace do
    param 'Any', :message
    return_type 'Undef'
  end

  def log_trace(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'log::trace'
      )
    end

    Puppet.lookup(:bolt_executor).tap do |executor|
      executor.report_function_call(self.class.name)
      executor.publish_event(type: :log, level: :trace, message: message)
    end

    nil
  end
end
