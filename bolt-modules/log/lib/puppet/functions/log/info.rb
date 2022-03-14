# frozen_string_literal: true

require 'bolt/util/format'

# Log an info message.
#
# Messages logged at this level typically include high-level information about
# what a plan is doing. For example, you might log a message at the `info` level
# that informs users that the plan is reading a file on disk.
#
# See [Logs](logs.md) for more information about Bolt's log levels.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'log::info') do
  # Log an info message.
  # @param message The message to log.
  # @example Log an info message
  #   log::info("Reading network device command file ${file}.")
  dispatch :log_info do
    param 'Any', :message
    return_type 'Undef'
  end

  def log_info(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        action: 'log::info'
      )
    end

    Puppet.lookup(:bolt_executor).tap do |executor|
      executor.report_function_call(self.class.name)
      executor.publish_event(type: :log, level: :info, message: Bolt::Util::Format.stringify(message))
    end

    nil
  end
end
