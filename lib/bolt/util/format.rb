# frozen_string_literal: true

module Bolt
  module Util
    module Format
      class << self
        # Stringifies an object, formatted as valid JSON.
        #
        # @param message [Object] The object to stringify.
        # @return [String] The JSON string.
        #
        def stringify(message)
          formatted = format_message(message)
          if formatted.is_a?(Hash) || formatted.is_a?(Array)
            ::JSON.pretty_generate(formatted)
          else
            formatted
          end
        end

        # Recursively formats an object into a format that can be represented by
        # JSON.
        #
        # @param message [Object] The object to stringify.
        # @return [Array, Hash, String]
        #
        private def format_message(message)
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

        # Formats a Bolt::ApplyResult object.
        #
        # @param result [Bolt::ApplyResult] The apply result.
        # @return [Hash]
        #
        private def format_apply_result(result)
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
    end
  end
end
