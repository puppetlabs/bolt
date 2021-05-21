# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class Docker < Simple
      class Connection
        attr_reader :user, :target

        def initialize(target)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host
          @target = target
          @user = ENV['USER'] || Etc.getlogin
          @logger = Bolt::Logger.logger(target.safe_name)
          @container_info = {}
          @docker_host = target.options['service-url']
          @logger.trace("Initializing docker connection to #{target.safe_name}")
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

        # The full ID of the target container
        #
        # @return [String] The full ID of the target container
        def container_id
          @container_info["Id"]
        end

        def run_cmd(cmd, env_vars)
          Bolt::Util.exec_docker(cmd, env_vars)
        end

        private def env_hash
          # Set the DOCKER_HOST if we are using a non-default service-url
          @docker_host.nil? ? {} : { 'DOCKER_HOST' => @docker_host }
        end

        def connect
          # We don't actually have a connection, but we do need to
          # check that the container exists and is running.
          output = execute_local_json_command('ps', ['--no-trunc'])
          index = output.find_index { |item| item["ID"].start_with?(target.host) || item["Names"] == target.host }
          raise "Could not find a container with name or ID matching '#{target.host}'" if index.nil?
          # Now find the indepth container information
          output = execute_local_json_command('inspect', [output[index]["ID"]])
          # Store the container information for later
          @container_info = output[0]
          @logger.trace { "Opened session" }
          true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def add_env_vars(env_vars)
          @env_vars = Bolt::Util.format_env_vars_for_cli(env_vars)
        end

        # Executes a command inside the target container. This is called from the shell class.
        #
        # @param command [string] The command to run
        def execute(command)
          args = []
          # CODEREVIEW: Is it always safe to pass --interactive?
          args += %w[--interactive]
          args += %w[--tty] if target.options['tty']
          args += @env_vars if @env_vars

          if target.options['shell-command'] && !target.options['shell-command'].empty?
            # escape any double quotes in command
            command = command.gsub('"', '\"')
            command = "#{target.options['shell-command']} \"#{command}\""
          end

          docker_command = %w[docker exec] + args + [container_id] + Shellwords.split(command)
          @logger.trace { "Executing: #{docker_command.join(' ')}" }

          Open3.popen3(env_hash, *docker_command)
        rescue StandardError
          @logger.trace { "Command aborted" }
          raise
        end

        def upload_file(source, destination)
          @logger.trace { "Uploading #{source} to #{destination}" }
          _out, err, stat = run_cmd(['cp', source, "#{container_id}:#{destination}"], env_hash)
          unless stat.exitstatus.zero?
            raise "Error writing to container #{container_id}: #{err}"
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def download_file(source, destination, _download)
          @logger.trace { "Downloading #{source} to #{destination}" }
          # Create the destination directory, otherwise copying a source directory with Docker will
          # copy the *contents* of the directory.
          # https://docs.docker.com/engine/reference/commandline/cp/
          FileUtils.mkdir_p(destination)
          _out, err, stat = run_cmd(['cp', "#{container_id}:#{source}", destination], env_hash)
          unless stat.exitstatus.zero?
            raise "Error downloading content from container #{container_id}: #{err}"
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        # Executes a Docker CLI command and parses the output in JSON format
        #
        # @param subcommand [String] The docker subcommand to run
        #   e.g. 'inspect' for `docker inspect`
        # @param arguments [Array] Arguments to pass to the docker command
        #   e.g. 'src' and 'dest' for `docker cp <src> <dest>
        # @return [Object] Ruby object representation of the JSON string
        def execute_local_json_command(subcommand, arguments = [])
          cmd = [subcommand, '--format', '{{json .}}'].concat(arguments)
          out, _err, _stat = run_cmd(cmd, env_hash)
          extract_json(out)
        end

        # Converts the JSON encoded STDOUT string from the docker cli into ruby objects
        #
        # @param stdout [String] The string to convert
        # @return [Object] Ruby object representation of the JSON string
        private def extract_json(stdout)
          # The output from the docker format command is a JSON string per line.
          # We can't do a direct convert but this helper method will convert it into
          # an array of Objects
          stdout.split("\n")
                .reject { |str| str.strip.empty? }
                .map { |str| JSON.parse(str) }
        end
      end
    end
  end
end
