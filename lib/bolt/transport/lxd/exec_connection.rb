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
            # TODO
        end

        def execute(command)
          # wrap "lxc exec remote:target --" here
        end

        def execute_local_lxc_command(subcommand, command_options = [], redir_stdin = nil)
            # TODO
            # set up streams
            # delegate to Open3.capture
        end

        def write_remote_directory(source, destination)
            #TODO
        end

        def write_remote_file(source, destination)
            #TODO
        end
      end
    end
  end
end