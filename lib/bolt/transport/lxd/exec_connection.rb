# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class LXD < Base
      class ExecConnection
        attr_reader :target

        def initialize(target)
          @target = target
          @lxd_remote = @target.config["lxd"]["remote"]
          @logger = Bolt::Logger.logger(target.safe_name)
          @logger.trace("")
        end

        def connect
            # TODO: check container is running

            # TODO: get info about container, store on self
            #@container_info = get_info
            
            true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{@target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def execute(*command, options)
          container = @target.name
          remote = @lxd_remote
          capture_options = { binmode: true }
          out, err, status = Open3.capture3('lxc', 'exec', "#{remote}:#{container}", 
            "--", *command, capture_options)
          [out, err, status]
        end

        def write_remote_directory(source, destination)
          container = @target.name
          remote = @lxd_remote
          # TODO: check dest is absolute path
          capture_options = { binmode: true }
          out, err, status = Open3.capture3('lxc', 'file', 'push', source,
            "#{remote}:#{container}#{destination}", "--recursive", capture_options)
        end

        def write_remote_file(source, destination)
          container = @target.name
          remote = @lxd_remote
          # TODO: check dest is absolute path
          capture_options = { binmode: true }
          out, err, status = Open3.capture3('lxc', 'file', 'push', source,
            "#{remote}:#{container}#{destination}",  capture_options)
        end

        def container_tmpdir
          '/tmp'
        end
      end
    end
  end
end