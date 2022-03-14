# frozen_string_literal: true

module Bolt
  class Plugin
    class Prompt
      def initialize(*_args); end

      def name
        'prompt'
      end

      def hooks
        hook_descriptions.keys
      end

      def hook_descriptions
        {
          resolve_reference: 'Prompt the user for a sensitive value.',
          validate_resolve_reference: nil
        }
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
