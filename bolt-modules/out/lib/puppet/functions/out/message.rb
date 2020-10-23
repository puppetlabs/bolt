# frozen_string_literal: true

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
    param 'Any', :message
    return_type 'Undef'
  end

  def output_message(message)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'out::message')
    end

    executor = Puppet.lookup(:bolt_executor)
    # Send Analytics Report
    executor.report_function_call(self.class.name)

    executor.publish_event(type: :message, message: stringify(message))

    nil
  end

  def stringify(message)
    formatted = format_message(message)
    if formatted.is_a?(Hash) || formatted.is_a?(Array)
      ::JSON.pretty_generate(formatted)
    else
      formatted
    end
  end

  def format_message(message)
    case message
    when Array
      message.map { |item| format_message(item) }
    when Bolt::ApplyResult
      format_apply_result(message)
    when Bolt::Result, Bolt::ResultSet
      # This is equivalent to to_s, but formattable
      message.to_data
    when Bolt::RunFailure
      formatted_resultset = message.result_set.to_data
      message.to_h.merge('result_set' => formatted_resultset)
    when Hash
      message.each_with_object({}) do |(k, v), h|
        h[format_message(k)] = format_message(v)
      end
    when Integer, Float, NilClass
      message
    else
      message.to_s
    end
  end

  def format_apply_result(result)
    logs = result.resource_logs&.map do |log|
      # Omit low-level info/debug messages
      next if %w[info debug].include?(log['level'])
      indent(2, format_log(log))
    end
    hash = result.to_data
    hash['logs'] = logs unless logs.empty?
    hash
  end
end
