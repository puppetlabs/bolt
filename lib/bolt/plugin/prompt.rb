# frozen_string_literal: true

module Bolt
  class Plugin
    class Prompt
      def initialize(*_args); end

      def name
        'prompt'
      end

      def hooks
        %i[resolve_reference validate_resolve_reference]
      end

      def validate_resolve_reference(opts)
        raise Bolt::ValidationError, "Prompt requires a 'message'" unless opts['message']
      end

      def resolve_reference(opts)
        $stderr.print("#{opts['message']}: ")
        value = $stdin.noecho(&:gets).to_s.chomp
        $stderr.puts

        value
      end
    end
  end
end
