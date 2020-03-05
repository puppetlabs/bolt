# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/base'

module Bolt
  module Transport
    class SSH < Base
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

      def run_command(target, command, options = {})
        with_connection(target) do |conn|
          conn.shell.run_command(command, options)
        end
      end

      def upload(target, source, destination, options = {})
        with_connection(target) do |conn|
          conn.shell.upload(source, destination, options)
        end
      end

      def run_script(target, script, arguments, options = {})
        with_connection(target) do |conn|
          conn.shell.run_script(script, arguments, options)
        end
      end

      def run_task(target, task, arguments, options = {})
        with_connection(target) do |conn|
          conn.shell.run_task(task, arguments, options)
        end
      end
    end
  end
end

require 'bolt/transport/ssh/connection'
