# frozen_string_literal: true

module Bolt
  class Outputter
    def self.for_format(format, color, trace)
      case format
      when 'human'
        Bolt::Outputter::Human.new(color, trace)
      when 'json'
        Bolt::Outputter::JSON.new(color, trace)
      when nil
        raise "Cannot use outputter before parsing."
      end
    end

    def initialize(color, trace, stream = $stdout)
      @color = color
      @trace = trace
      @stream = stream
    end
  end
end

require 'bolt/outputter/human'
require 'bolt/outputter/json'
