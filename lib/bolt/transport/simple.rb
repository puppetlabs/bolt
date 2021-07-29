# frozen_string_literal: true

require 'logging'
require_relative '../../bolt/result'
require_relative '../../bolt/shell'
require_relative '../../bolt/transport/base'

module Bolt
  module Transport
    # A simple transport has a single connection per target and delegates its
    # operation to a target-specific shell.
    class Simple < Base
      def with_connection(_target)
        raise NotImplementedError, "with_connection() must be implemented by the transport class"
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end

      def run_command(target, command, options = {}, position = [])
        with_connection(target) do |conn|
          conn.shell.run_command(command, options, position)
        end
      end

      def upload(target, source, destination, options = {})
        with_connection(target) do |conn|
          conn.shell.upload(source, destination, options)
        end
      end

      def download(target, source, destination, options = {})
        with_connection(target) do |conn|
          conn.shell.download(source, destination, options)
        end
      end

      def run_script(target, script, arguments, options = {}, position = [])
        with_connection(target) do |conn|
          conn.shell.run_script(script, arguments, options, position)
        end
      end

      def run_task(target, task, arguments, options = {}, position = [])
        with_connection(target) do |conn|
          conn.shell.run_task(task, arguments, options, position)
        end
      end
    end
  end
end
