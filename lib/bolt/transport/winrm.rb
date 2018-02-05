require 'bolt/transport/winrm/connection'
require 'logging'

module Bolt
  module Transport
    class WinRM
      attr_reader :logger

      def initialize(_config)
        @logger = Logging.logger[self]

        require 'winrm'
        require 'winrm-fs'
      end

      def with_connection(target)
        conn = Connection.new(target)
        conn.connect
        yield conn
      ensure
        conn.disconnect if conn
      end

      def upload(target, source, destination, options = {})
        with_connection(target) do |conn|
          conn.upload(source, destination, options)
        end
      end

      def run_command(target, command, options = {})
        with_connection(target) do |conn|
          conn.run_command(command, options)
        end
      end

      def run_script(target, script, arguments, options = {})
        with_connection(target) do |conn|
          conn.run_script(script, arguments, options)
        end
      end

      def run_task(target, task, inputmethod, arguments, options = {})
        with_connection(target) do |conn|
          conn.run_task(task, inputmethod, arguments, options)
        end
      end
    end
  end
end
