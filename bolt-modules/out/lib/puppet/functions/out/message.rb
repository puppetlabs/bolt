# frozen_string_literal: true

require 'bolt/pal/issues'

# Output a message for the user.
#
# This will print a message to stdout when using the human output format,
# and print to stderr when using the json output format
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:'out::message') do
  # Output a message.
  # @param message The message to output.
  # @example Print a message
  #   out::message('Something went wrong')
  dispatch :output_message do
    param 'String', :message
    return_type 'Undef'
  end

  def output_message(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'out::message')
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)
    executor.publish_event(type: :message, message: message)

    nil
  end
end
