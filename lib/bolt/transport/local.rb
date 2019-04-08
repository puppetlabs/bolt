# frozen_string_literal: true

module Bolt
  module Transport
    class Local < Sudoable
      def self.options
        %w[tmpdir interpreters sudo-password run-as run-as-command]
      end

      def provided_features
        ['shell']
      end

      def self.validate(options)
        logger = Logging.logger[self]
        validate_sudo_options(options, logger)
      end

      def with_connection(target, *_args)
        conn = Shell.new(target)
        yield conn
      end

      def connected?(_targets)
        true
      end
    end
  end
end

require 'bolt/transport/local/shell'
