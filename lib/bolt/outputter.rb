# frozen_string_literal: true

module Bolt
  class Outputter
    def self.for_format(format, color, verbose, trace, spin)
      case format
      when 'human'
        Bolt::Outputter::Human.new(color, verbose, trace, spin)
      when 'json'
        Bolt::Outputter::JSON.new(color, verbose, trace, false)
      when 'rainbow'
        Bolt::Outputter::Rainbow.new(color, verbose, trace, spin)
      when 'quiet'
        Bolt::Outputter::Quiet.new(color, verbose, trace, spin)
      when nil
        raise "Cannot use outputter before parsing."
      end
    end

    def initialize(color, verbose, trace, spin, stream = $stdout)
      @color = color
      @verbose = verbose
      @trace = trace
      @stream = stream
      @spin = spin
    end

    def indent(indent, string)
      indent = ' ' * indent
      string.gsub(/^/, indent.to_s)
    end

    def print_message
      raise NotImplementedError, "print_message() must be implemented by the outputter class"
    end

    def print_error
      raise NotImplementedError, "print_error() must be implemented by the outputter class"
    end

    def start_spin; end

    def stop_spin; end

    def spin
      start_spin
      begin
        yield
      ensure
        stop_spin
      end
    end
  end
end

require 'bolt/outputter/human'
require 'bolt/outputter/json'
require 'bolt/outputter/logger'
require 'bolt/outputter/rainbow'
require 'bolt/outputter/quiet'
