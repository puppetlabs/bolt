# frozen_string_literal: true

require_relative '../../bolt/node/errors'
require_relative '../../bolt/transport/base'

module Bolt
  module Transport
    class WinRM < Simple
      def initialize
        super
        require 'winrm'
        require 'winrm-fs'

        @transport_logger = Bolt::Logger.logger(::WinRM)
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

require_relative 'winrm/connection'
