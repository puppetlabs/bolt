# frozen_string_literal: true

require 'concurrent/delay'
module Bolt
  class Plugin
    class Prompt
      def initialize
        # Might not need this
        @logger = Logging.logger[self]
      end

      def name
        'prompt'
      end

      def hooks
        ['inventory_config_lookup']
      end

      def validate_inventory_config_lookup(opts)
        raise Bolt::ValidationError, "Prompt requires a 'message'" unless opts['message']
      end

      def inventory_config_lookup(opts)
        STDOUT.print "#{opts['message']}:"
        value = STDIN.noecho(&:gets).chomp
        STDOUT.puts
        value
      end
    end
  end
end
