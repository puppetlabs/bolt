# frozen_string_literal: true

require 'bolt/transport/base'

module Bolt
  module Transport
    class Local < Base
      def connected?(_targets)
        true
      end

      def connection(target)
        Connection.new(target)
      end

      def run_command(target, command, options = {})
        connection(target).shell.run_task(command, options)
      end

      def upload(target, source, destination, options = {})
        connection(target).shell.upload(source, destination, options)
      end

      def run_script(target, script, arguments, options = {})
        connection(target).shell.run_script(script, arguments, options)
      end

      def run_task(target, task, arguments, options = {})
        connection(target).shell.run_task(task, arguments, options)
      end
    end
  end
end

require 'bolt/transport/local/connection'
