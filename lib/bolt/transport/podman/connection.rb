# frozen_string_literal: true

require 'logging'
require_relative '../../../bolt/node/errors'

module Bolt
  module Transport
    class Podman < Docker
      class Connection < Connection
        attr_reader :user, :target

        def initialize(target)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host
          @target = target
          @user = ENV['USER'] || Etc.getlogin
          @logger = Bolt::Logger.logger(target.safe_name)
          @container_info = {}
          @logger.trace("Initializing podman connection to #{target.safe_name}")
        end

        def run_cmd(cmd, env_vars)
          Bolt::Util.exec_podman(cmd, env_vars)
        end

        def shell
          @shell ||= if Bolt::Util.windows?
                       Bolt::Shell::Powershell.new(target, self)
                     else
                       Bolt::Shell::Bash.new(target, self)
                     end
        end

        def reset_cwd?
          true
        end

        def connect
          # We don't actually have a connection, but we do need to
          # check that the container exists and is running.
          ps = execute_local_json_command('ps')
          container = Array(ps).find { |item|
            item["ID"].to_s.eql?(@target.host) ||
              item["Id"].to_s.start_with?(@target.host) ||
              Array(item["Names"]).include?(@target.host)
          }
          raise "Could not find a container with name or ID matching '#{@target.host}'" if container.nil?
          # Now find the indepth container information
          id = container["ID"] || container["Id"]
          output = execute_local_json_command('inspect', [id])
          # Store the container information for later
          @container_info = output.first
          @logger.trace { "Opened session" }
          true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        # Executes a command inside the target container. This is called from the shell class.
        #
        # @param command [string] The command to run
        def execute(command)
          args = []
          args += %w[--interactive]
          args += %w[--tty] if target.options['tty']
          args += @env_vars if @env_vars

          if target.options['shell-command'] && !target.options['shell-command'].empty?
            # escape any double quotes in command
            command = command.gsub('"', '\"')
            command = "#{target.options['shell-command']} \"#{command}\""
          end

          podman_command = %w[podman exec] + args + [container_id] + Shellwords.split(command)
          @logger.trace { "Executing: #{podman_command.join(' ')}" }

          Open3.popen3(*podman_command)
        rescue StandardError
          @logger.trace { "Command aborted" }
          raise
        end

        # Converts the JSON encoded STDOUT string from the podman cli into ruby objects
        #
        # @param stdout [String] The string to convert
        # @return [Object] Ruby object representation of the JSON string
        private def extract_json(stdout)
          # Podman renders the output in pretty JSON, which results in a newline
          # appearing in the output before the closing bracket.
          # should we only get a single line with no newline at all, we also
          # assume it is a single minified JSON object
          stdout.strip!
          newline = stdout.index("\n") || -1
          bracket = stdout.index('}') || -1
          JSON.parse(stdout) if bracket > newline
        end
      end
    end
  end
end
