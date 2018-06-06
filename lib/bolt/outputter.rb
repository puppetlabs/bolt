# frozen_string_literal: true

module Bolt
  class Outputter
    def self.for_format(format, color)
      case format
      when 'human'
        Bolt::Outputter::Human.new(color)
      when 'json'
        Bolt::Outputter::JSON.new(color)
      when nil
        raise "Cannot use outputter before parsing."
      end
    end

    def initialize(color, stream = $stdout)
      @color = color
      @stream = stream
    end

    # This method replaces data types tha have the name 'Data'
    # with the string 'Any'
    # This was a problem when using 'bolt task show <task_name>'
    def replace_data_type(params)
      params.map do |_, v|
        v['type'] = 'Any' if v['type'].to_s == 'Data'
      end
    end
  end
end

require 'bolt/outputter/human'
require 'bolt/outputter/json'
