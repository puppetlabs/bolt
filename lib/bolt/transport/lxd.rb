# frozen_string_literal: true

require 'bolt/logger'
require 'bolt/node/errors'
require 'bolt/transport/simple'

module Bolt
  module Transport
    class LXD < Base
      def provided_features
        ['shell']
      end

      def with_connection(target)
        conn = ExecConnection.new(target) # make "remote" another param?
        conn.connect
        yield conn
      end

      def self.validate(options)
        if (url = options['service-url'])
          unless url.instance_of?(String)
            raise Bolt::ValidationError, 'service-url must be a string'
          end
        end
      end

      def upload(target, source, destination, _options = {})
        with_connection(target) do |conn|
          if File.directory?(source)
            conn.write_remote_directory(source, destination)
          else
            conn.write_remote_file(source, destination)
          end
        Bolt::Result.for_upload(target, source, destination)
        end
      end

      def download(target, source, destination, _options = {})
        with_connection(target) do |conn|
          # TODO
          stdout, stderr, exitcode = conn.download_file(source, destination)
        end
        Bolt::Result.for_download(target, source, destination)
      end

      def run_command(target, command, options = {}, position)
        with_connection(target) do |conn|
          # TODO: what about
          # * environment variables
          # * "run as" user (lxc supports this)
          execute_options = {}
          stdout, stderr, exitcode = conn.execute(*Shellwords.split(command), execute_options)
          Bolt::Result.for_command(target, stdout, stderr, exitcode, 'command', command, position)
        end
      end

      def run_script(target, script, arguments, options = {})
        #TODO, upload and execute
      end

      def run_task(target, task, arguments, _options = {})
        #TODO
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end

    end
  end
end

require 'bolt/transport/lxd/exec_connection'
