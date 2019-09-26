# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class Docker < Base
      class Connection
        # Holds information about the Docker server per service-url
        # Hash[String, Hash]
        @@docker_server_information = {} # rubocop:disable Style/ClassVars This is acceptable

        def initialize(target)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host
          @target = target
          @logger = Logging.logger[target.safe_name]
          @docker_host = @target.options['service-url']
          @logger.debug("Initializing docker connection to #{@target.safe_name}")
        end

        # Connects to the docker host and verifies the target exists
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

        # rubocop:disable Metrics/LineLength
        # Executes a command inside the target container
        #
        # @param command [Array] The command to run, expressed as an array of strings
        # @param options [Hash] command specific options
        # @option opts [Array<String>] :interpreter statements that are prefixed to the command e.g `/bin/bash` or `['cmd.exe', '/c']`
        # @option opts [Hash] :environment A hash of environment variables that will be injected into the command
        # @option opts [IO] :stdin An IO object that will be used to redirect STDIN for the docker command
        # rubocop:enable Metrics/LineLength
        def execute(*command, options)
          if options[:interpreter]
            if options[:interpreter].is_a?(Array)
              command.unshift(*options[:interpreter])
            else
              command.unshift(options[:interpreter])
            end
          end
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
          if supports_file_operations_while_running?
            write_remote_file_via_cp(source, destination)
          else
            write_remote_file_via_powershell(source, destination)
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def write_remote_directory(source, destination)
          @logger.debug { "Uploading #{source}, to #{destination}" }
          if supports_file_operations_while_running?
            write_remote_directory_via_cp(source, destination)
          else
            write_remote_directory_via_powershell(source, destination)
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def mkdirs(dirs)
          if windows_container?
            dirs.each do |dir|
              # mkdir in cmd ONLY uses backslashes
              windows_dir = Bolt::Util.windows_path(dir)
              _, stderr, exitcode = execute(
                'cmd.exe', '/c', 'IF', 'NOT', 'EXIST', windows_dir, '(MKDIR', windows_dir, ')',
                {}
              )
              if exitcode != 0
                message = "Could not create directories: #{stderr}"
                raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
              end
            end
            return
          end
          _, stderr, exitcode = execute('mkdir', '-p', *dirs, {})

          if exitcode != 0
            message = "Could not create directories: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def make_tempdir
          tmpdir = @target.options.fetch('tmpdir', container_tmpdir)
          tmppath = "#{tmpdir}/#{SecureRandom.uuid}"

          if windows_container? # rubocop:disable Style/ConditionalAssignment
            # On Modern Windows, mkdir will quite happily make all intermediate directories whereas on
            # Linux it needs the -p flag. Therefore we make a one-line batch command to emulate the behaviour
            # of linux mkdir
            # Note - mkdir in cmd ONLY uses backslashes
            command = [
              'cmd.exe', '/c', 'IF', 'NOT', 'EXIST', Bolt::Util.windows_path(tmpdir),
              '(', 'ECHO', 'Could', 'not', 'make', 'tempdir', Bolt::Util.windows_path(tmppath), '1>&2',
              '&&', 'EXIT', '/B', '1', ')',
              'ELSE',
              '(', 'mkdir', Bolt::Util.windows_path(tmppath), ')'
            ]
          else
            command = ['mkdir', '-m', '700', tmppath]
          end
          stdout, stderr, exitcode = execute(*command, {})

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
            if windows_container? # rubocop:disable Style/ConditionalAssignment
              # rd in cmd ONLY uses backslashes
              command = ['cmd.exe', '/c', 'rd', Bolt::Util.windows_path(dir), '/s', '/q']
            else
              command = ['rm', '-rf', dir]
            end
            _, stderr, exitcode = execute(*command, {})
            if exitcode != 0
              @logger.warn("Failed to clean up tempdir '#{dir}': #{stderr}")
            end
          end
        end

        def write_remote_executable(dir, file, filename = nil)
          filename ||= File.basename(file)
          remote_path = File.join(dir.to_s, filename)
          write_remote_file(file, remote_path)
          # Windows containers don't support posix style permissions so
          # exit early and return the Windows version of the path. This is required
          # because this may be used by the cmd.exe shell which requires backslashes
          return Bolt::Util.windows_path(remote_path) if windows_container?
          make_executable(remote_path)
          remote_path
        end

        def make_executable(path)
          # Windows containers don't support posix style permissions so exit early
          return if windows_container?
          _, stderr, exitcode = execute('chmod', 'u+x', path, {})
          if exitcode != 0
            message = "Could not make file '#{path}' executable: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'CHMOD_ERROR')
          end
        end

        def windows_container?
          @container_info["Platform"] == "windows"
        end

        private

        def supports_file_operations_while_running?
          # HyperV based isolation does not support file operations (e.g. docker cp) on running Windows containers
          docker_server_information['Isolation'] != 'hyperv'
        end

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

        # rubocop:disable Layout/LineLength
        # Executes a Docker CLI command
        #
        # @param subcommand [String] The docker subcommand to run e.g. 'inspect' for `docker inspect`
        # @param command_options [Array] Additional command options e.g. ['--size'] for `docker inspect --size`
        # @param redir_stdin [IO] IO object which will be use to as STDIN in the docker command. Default is nil, which does not perform redirection
        # @return [String, String, Process::Status] The output of the command:  STDOUT, STDERR, Process Status
        # rubocop:enable Layout/LineLength
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
          return @tmp_dir unless @tmp_dir.nil?
          unless windows_container?
            # Linux containers will always have /tmp
            @tmp_dir = '/tmp'
            return @tmp_dir
          end

          stdout, stderr, exitcode = execute('cmd.exe', '/c', 'echo', '%TEMP%', {})
          if exitcode != 0
            message = "Could not determine tmpdir: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'TMPDIR_ERROR')
          end
          @tmp_dir = stdout.chomp.strip
        end

        # Information about the Docker Server
        # @return [Hash] Ruby Hash of the `docker info` command
        def docker_server_information
          service_url = @docker_host || '<local>'
          return @@docker_server_information[service_url] unless @@docker_server_information[service_url].nil?
          @@docker_server_information[service_url] = execute_local_docker_json_command('info')[0]
        end

        def write_remote_file_via_cp(source, destination)
          _, stdout_str, status = execute_local_docker_command('cp', [source, "#{container_id}:#{destination}"])
          raise "Error writing directory to container #{@container_id}: #{stdout_str}" unless status.exitstatus.zero?
        end

        def powershell_args
          %w[-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass]
        end

        def execute_local_powershell_command(ps_command)
          encoded_command = Base64.strict_encode64(ps_command.encode('UTF-16LE'))
          local_command = powershell_args.concat(['-EncodedCommand', encoded_command])
          Open3.capture3('powershell.exe', *local_command)
        end

        def write_remote_file_via_powershell(source, destination)
          ps_command = "Copy-Item -Path \"#{source}\" -Destination \"#{destination}\" -Force -Confirm:$false" \
                       " -ErrorAction 'Stop' -ToSession (New-PSSession -ContainerId '#{container_id}'" \
                       " -RunAsAdministrator)"
          _, stderr_str, status = execute_local_powershell_command(ps_command)
          raise Bolt::Node::FileError.new(stderr_str, 'WRITE_ERROR') unless status.exitstatus.zero?
        end

        def write_remote_directory_via_cp(source, destination)
          _, stdout_str, status = execute_local_docker_command('cp', [source, "#{container_id}:#{destination}"])
          raise "Error writing directory to container #{@container_id}: #{stdout_str}" unless status.exitstatus.zero?
        end

        def write_remote_directory_via_powershell(source, destination)
          ps_command = "Copy-Item -Path \"#{source}\" -Destination \"#{destination}\" -Recurse -Force -Confirm:$false" \
                       " -ErrorAction 'Stop' -ToSession (New-PSSession -ContainerId '#{container_id}'" \
                       " -RunAsAdministrator)"
          _, stderr_str, status = execute_local_powershell_command(ps_command)
          raise Bolt::Node::FileError.new(stderr_str, 'WRITE_ERROR') unless status.exitstatus.zero?
        end
      end
    end
  end
end
