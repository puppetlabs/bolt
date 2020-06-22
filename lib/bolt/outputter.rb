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
  end
end

require 'bolt/outputter/human'
require 'bolt/outputter/json'
require 'bolt/outputter/rainbow'
require 'bolt/outputter/logger'
