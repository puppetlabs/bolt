# frozen_string_literal: true

module Bolt
  class Outputter
    def self.for_format(format, color, verbose, trace)
      case format
      when 'human'
        Bolt::Outputter::Human.new(color, verbose, trace)
      when 'json'
        Bolt::Outputter::JSON.new(color, verbose, trace)
      when 'rainbow'
        Bolt::Outputter::Rainbow.new(color, verbose, trace)
      when nil
        raise "Cannot use outputter before parsing."
      end
    end

    def initialize(color, verbose, trace, stream = $stdout)
      @color = color
      @verbose = verbose
      @trace = trace
      @stream = stream
    end

    def indent(indent, string)
      indent = ' ' * indent
      string.gsub(/^/, indent.to_s)
    end

    def print_message_event(event)
      print_message(stringify(event[:message]))
    end

    def print_message
      raise NotImplementedError, "print_message() must be implemented by the outputter class"
    end

    def print_error
      raise NotImplementedError, "print_error() must be implemented by the outputter class"
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
end

require 'bolt/outputter/human'
require 'bolt/outputter/json'
require 'bolt/outputter/logger'
require 'bolt/outputter/rainbow'
