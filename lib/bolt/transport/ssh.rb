# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/simple'

module Bolt
  module Transport
    class SSH < Simple
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
    end
  end
end

require 'bolt/transport/ssh/connection'
