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
