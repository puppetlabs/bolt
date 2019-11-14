# frozen_string_literal: true

require 'concurrent/delay'
module Bolt
  class Plugin
    class Prompt
      def initialize(*_args); end

      def name
        'prompt'
      end

      def hooks
        [:resolve_reference]
      end

      def validate_resolve_reference(opts)
        raise Bolt::ValidationError, "Prompt requires a 'message'" unless opts['message']
      end

      def resolve_reference(opts)
        # rubocop:disable Style/GlobalVars
        $future ? STDERR.print("#{opts['message']}: ") : STDOUT.print("#{opts['message']}: ")
        value = STDIN.noecho(&:gets).chomp
        $future ? STDERR.puts : STDOUT.puts
        # rubocop:enable Style/GlobalVars

        value
      end
    end
  end
end
