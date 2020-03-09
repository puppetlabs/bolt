# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/sudoable'
require 'json'
require 'shellwords'

module Bolt
  module Transport
    class SSH < Sudoable
      def provided_features
        ['shell']
      end

      def initialize
        super

        require 'net/ssh'
        require 'net/scp'
        begin
          require 'net/ssh/krb'
        rescue LoadError
          logger.debug("Authentication method 'gssapi-with-mic' (Kerberos) is not available.")
        end

        @transport_logger = Logging.logger[Net::SSH]
        @transport_logger.level = :warn
      end

      def with_connection(target)
        conn = Connection.new(target, @transport_logger)
        conn.connect
        yield conn
      ensure
        begin
          conn&.disconnect
        rescue StandardError => e
          logger.info("Failed to close connection to #{target.safe_name} : #{e.message}")
        end
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end
    end
  end
end

require 'bolt/transport/ssh/connection'
