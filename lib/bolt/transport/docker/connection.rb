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

        # The full ID of the target container
        #
        # @return [String] The full ID of the target container
        def container_id
          @container_info["Id"]
        end

        def connect
          # We don't actually have a connection, but we do need to
          # check that the container exists and is running.
          output = execute_local_docker_json_command('ps')
          index = output.find_index { |item| item["ID"] == target.host || item["Names"] == target.host }
          raise "Could not find a container with name or ID matching '#{target.host}'" if index.nil?
          # Now find the indepth container information
          output = execute_local_docker_json_command('inspect', [output[index]["ID"]])
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

        # Executes a command inside the target container. This is called from the shell class.
        #
        # @param command [string] The command to run
        def execute(command)
          args = %w[-i]
          args << %w[--tty] if target.options['tty']
          args << %W[--env DOCKER_HOST=#{@docker_host}] if @docker_host
          # CODEREVIEW: Is it always safe to run with -i?
          docker_command = %W[docker exec #{args.join} #{container_id} sh -c #{command}]
          @logger.trace { "Executing: #{docker_command}" }

          Open3.popen3(*docker_command)
        rescue StandardError
          @logger.trace { "Command aborted" }
          raise
        end

        def upload_file(source, destination)
          @logger.trace { "Uploading #{source} to #{destination}" }
          _stdout, stderr, status = execute_local_docker_command('cp', [source, "#{container_id}:#{destination}"])
          unless status.exitstatus.zero?
            raise "Error writing to container #{container_id}: #{stderr}"
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
          _stdout, stderr, status = execute_local_docker_command('cp', ["#{container_id}:#{source}", destination])
          unless status.exitstatus.zero?
            raise "Error downloading content from container #{container_id}: #{stderr}"
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        # Executes a Docker CLI command. This is useful for running commands as
        # part of this class without having to go through the `execute`
        # function and manage pipes.
        #
        # @param subcommand [String] The docker subcommand to run
        #   e.g. 'inspect' for `docker inspect`
        # @param arguments [Array] Arguments to pass to the docker command
        #   e.g. 'src' and 'dest' for `docker cp <src> <dest>
        # @return [String, String, Process::Status] The output of the command: STDOUT, STDERR, Process Status
        private def execute_local_docker_command(subcommand, arguments = [])
          # Set the DOCKER_HOST if we are using a non-default service-url
          env_hash = @docker_host.nil? ? {} : { 'DOCKER_HOST' => @docker_host }
          docker_command = [subcommand].concat(arguments)

          Open3.capture3(env_hash, 'docker', *docker_command, { binmode: true })
        end

        # Executes a Docker CLI command and parses the output in JSON format
        #
        # @param subcommand [String] The docker subcommand to run
        #   e.g. 'inspect' for `docker inspect`
        # @param arguments [Array] Arguments to pass to the docker command
        #   e.g. 'src' and 'dest' for `docker cp <src> <dest>
        # @return [Object] Ruby object representation of the JSON string
        private def execute_local_docker_json_command(subcommand, arguments = [])
          command_options = ['--format', '{{json .}}'].concat(arguments)
          stdout, _stderr, _status = execute_local_docker_command(subcommand, command_options)
          extract_json(stdout)
        end

        # Converts the JSON encoded STDOUT string from the docker cli into ruby objects
        #
        # @param stdout_string [String] The string to convert
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
