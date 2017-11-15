module Bolt
  class Outputter
    def self.for_format(format)
      case format
      when 'human'
        Bolt::Outputter::Human.new
      when 'json'
        Bolt::Outputter::JSON.new
      when nil
        raise "Cannot use outputter before parsing."
      end
    end

    def initialize(stream = $stdout)
      @stream = stream
    end
  end
end

require 'bolt/outputter/human'
require 'bolt/outputter/json'
