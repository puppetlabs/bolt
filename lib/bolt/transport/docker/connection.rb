# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class Docker < Base
      class Connection
        def initialize(target)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host
          @target = target
          @logger = Logging.logger[target.safe_name]
          @docker_host = @target.options['service-url']
        end

        def connect
          # We don't actually have a connection, but we do need to
          # check that the container exists and is running.
          output = execute_local_docker_json_command('ps')
          index = output.find_index { |item| item["ID"] == @target.host || item["Names"] == @target.host }
          raise "Could not find a container with name or ID matching '#{@target.host}'" if index.nil?
          # Now find the indepth container information
          output = execute_local_docker_json_command('inspect', [output[index]["ID"]])
          # Store the container information for later
          @container_info = output[0]
          @logger.debug { "Opened session" }
          true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{@target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        # Executes a command inside the target container
        #
        # @param command [Array] The command to run, expressed as an array of strings
        # @param options [Hash] command specific options
        # @option opts [String] :interpreter statements that are prefixed to the command e.g `/bin/bash` or `cmd.exe /c`
        # @option opts [Hash] :environment A hash of environment variables that will be injected into the command
        # @option opts [IO] :stdin An IO object that will be used to redirect STDIN for the docker command
        def execute(*command, options)
          command.unshift(options[:interpreter]) if options[:interpreter]
          # Build the `--env` parameters
          envs = []
          if options[:environment]
            options[:environment].each { |env, val| envs.concat(['--env', "#{env}=#{val}"]) }
          end

          command_options = []
          # Need to be interactive if redirecting STDIN
          command_options << '--interactive' unless options[:stdin].nil?
          command_options << '--tty' if options[:tty]
          command_options.concat(envs) unless envs.empty?
          command_options << container_id
          command_options.concat(command)

          @logger.debug { "Executing: exec #{command_options}" }

          stdout_str, stderr_str, status = execute_local_docker_command('exec', command_options, options[:stdin])

          # The actual result is the exitstatus not the process object
          status = status.nil? ? -32768 : status.exitstatus
          if status == 0
            @logger.debug { "Command returned successfully" }
          else
            @logger.info { "Command failed with exit code #{status}" }
          end
          stdout_str.force_encoding(Encoding::UTF_8)
          stderr_str.force_encoding(Encoding::UTF_8)
          # Normalise line endings
          stdout_str.gsub!("\r\n", "\n")
          stderr_str.gsub!("\r\n", "\n")
          [stdout_str, stderr_str, status]
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def write_remote_file(source, destination)
          @logger.debug { "Uploading #{source}, to #{destination}" }
          _, stdout_str, status = execute_local_docker_command('cp', [source, "#{container_id}:#{destination}"])
          raise "Error writing file to container #{@container_id}: #{stdout_str}" unless status.exitstatus.zero?
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def write_remote_directory(source, destination)
          @logger.debug { "Uploading #{source}, to #{destination}" }
          _, stdout_str, status = execute_local_docker_command('cp', [source, "#{container_id}:#{destination}"])
          raise "Error writing directory to container #{@container_id}: #{stdout_str}" unless status.exitstatus.zero?
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def mkdirs(dirs)
          _, stderr, exitcode = execute('mkdir', '-p', *dirs, {})
          if exitcode != 0
            message = "Could not create directories: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def make_tempdir
          tmpdir = @target.options.fetch('tmpdir', container_tmpdir)
          tmppath = "#{tmpdir}/#{SecureRandom.uuid}"

          stdout, stderr, exitcode = execute('mkdir', '-m', '700', tmppath, {})
          if exitcode != 0
            raise Bolt::Node::FileError.new("Could not make tempdir: #{stderr}", 'TEMPDIR_ERROR')
          end
          tmppath || stdout.first
        end

        def with_remote_tempdir
          dir = make_tempdir
          yield dir
        ensure
          if dir
            _, stderr, exitcode = execute('rm', '-rf', dir, {})
            if exitcode != 0
              @logger.warn("Failed to clean up tempdir '#{dir}': #{stderr}")
            end
          end
        end

        def write_remote_executable(dir, file, filename = nil)
          filename ||= File.basename(file)
          remote_path = File.join(dir.to_s, filename)
          write_remote_file(file, remote_path)
          make_executable(remote_path)
          remote_path
        end

        def make_executable(path)
          _, stderr, exitcode = execute('chmod', 'u+x', path, {})
          if exitcode != 0
            message = "Could not make file '#{path}' executable: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'CHMOD_ERROR')
          end
        end

        private

        # Converts the JSON encoded STDOUT string from the docker cli into ruby objects
        #
        # @param stdout_string [String] The string to convert
        # @return [Object] Ruby object representation of the JSON string
        def extract_json(stdout_string)
          # The output from the docker format command is a JSON string per line.
          # We can't do a direct convert but this helper method will convert it into
          # an array of Objects
          stdout_string.split("\n")
                       .reject { |str| str.strip.empty? }
                       .map { |str| JSON.parse(str) }
        end

        # rubocop:disable Metrics/LineLength
        # Executes a Docker CLI command
        #
        # @param subcommand [String] The docker subcommand to run e.g. 'inspect' for `docker inspect`
        # @param command_options [Array] Additional command options e.g. ['--size'] for `docker inspect --size`
        # @param redir_stdin [IO] IO object which will be use to as STDIN in the docker command. Default is nil, which does not perform redirection
        # @return [String, String, Process::Status] The output of the command:  STDOUT, STDERR, Process Status
        # rubocop:enable Metrics/LineLength
        def execute_local_docker_command(subcommand, command_options = [], redir_stdin = nil)
          env_hash = {}
          # Set the DOCKER_HOST if we are using a non-default service-url
          env_hash['DOCKER_HOST'] = @docker_host unless @docker_host.nil?

          command_options = [] if command_options.nil?
          docker_command = [subcommand].concat(command_options)

          # Always use binary mode for any text data
          capture_options = { binmode: true }
          capture_options[:stdin_data] = redir_stdin unless redir_stdin.nil?
          stdout_str, stderr_str, status = Open3.capture3(env_hash, 'docker', *docker_command, capture_options)
          [stdout_str, stderr_str, status]
        end

        # Executes a Docker CLI command and parses the output in JSON format
        #
        # @param subcommand [String] The docker subcommand to run e.g. 'inspect' for `docker inspect`
        # @param command_options [Array] Additional command options e.g. ['--size'] for `docker inspect --size`
        # @return [Object] Ruby object representation of the JSON string
        def execute_local_docker_json_command(subcommand, command_options = [])
          command_options = [] if command_options.nil?
          command_options = ['--format', '{{json .}}'].concat(command_options)
          stdout_str, _stderr_str, _status = execute_local_docker_command(subcommand, command_options)
          extract_json(stdout_str)
        end

        # The full ID of the target container
        #
        # @return [String] The full ID of the target container
        def container_id
          @container_info["Id"]
        end

        # The temp path inside the target container
        #
        # @return [String] The absolute path to the temp directory
        def container_tmpdir
          '/tmp'
        end
      end
    end
  end
end
