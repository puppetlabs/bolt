# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/node/output'

module Bolt
  module Transport
    class WinRM < Base
      class Connection
        attr_reader :logger, :target

        DEFAULT_EXTENSIONS = ['.ps1', '.rb', '.pp'].freeze

        def initialize(target, transport_logger)
          raise Bolt::ValidationError, "Target #{target.name} does not have a host" unless target.host
          @target = target

          default_port = target.options['ssl'] ? HTTPS_PORT : HTTP_PORT
          @port = @target.port || default_port
          @user = @target.user
          # Build set of extensions from extensions config as well as interpreters
          extensions = [target.options['extensions'] || []].flatten.map { |ext| ext[0] != '.' ? '.' + ext : ext }
          extensions += target.options['interpreters'].keys if target.options['interpreters']
          @extensions = DEFAULT_EXTENSIONS.to_set.merge(extensions)

          @logger = Logging.logger[@target.host]
          @transport_logger = transport_logger
        end

        HTTP_PORT = 5985
        HTTPS_PORT = 5986

        def connect
          if target.options['ssl']
            scheme = 'https'
            transport = :ssl
          else
            scheme = 'http'
            transport = :negotiate
          end
          endpoint = "#{scheme}://#{target.host}:#{@port}/wsman"
          options = { endpoint: endpoint,
                      user: @user,
                      password: target.password,
                      retry_limit: 1,
                      transport: transport,
                      ca_trust_path: target.options['cacert'],
                      no_ssl_peer_verification: !target.options['ssl-verify'] }

          Timeout.timeout(target.options['connect-timeout']) do
            @connection = ::WinRM::Connection.new(options)
            @connection.logger = @transport_logger

            @session = @connection.shell(:powershell)
            @session.run('$PSVersionTable.PSVersion')
            @logger.debug { "Opened session" }
          end
        rescue Timeout::Error
          # If we're using the default port with SSL, a timeout probably means the
          # host doesn't support SSL.
          if target.options['ssl'] && @port == HTTPS_PORT
            the_problem = "\nVerify that required WinRM ports are open, " \
                          "or use --no-ssl if this host isn't configured to use SSL for WinRM."
          end
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{endpoint}#{the_problem}",
            'CONNECT_ERROR'
          )
        rescue ::WinRM::WinRMAuthorizationError
          raise Bolt::Node::ConnectError.new(
            "Authentication failed for #{endpoint}",
            'AUTH_ERROR'
          )
        rescue OpenSSL::SSL::SSLError => e
          # If we're using SSL with the default non-SSL port, mention that as a likely problem
          if target.options['ssl'] && @port == HTTP_PORT
            theres_your_problem = "\nAre you using SSL to connect to a non-SSL port?"
          end
          if target.options['ssl-verify'] && e.message.include?('certificate verify failed')
            theres_your_problem = "\nIs the remote host using a self-signed SSL"\
                                  "certificate? Use --no-ssl-verify to disable "\
                                  "remote host SSL verification."
          end
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{endpoint}: #{e.message}#{theres_your_problem}",
            "CONNECT_ERROR"
          )
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{endpoint}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def disconnect
          @session&.close
          @client&.disconnect!
          @logger.debug { "Closed session" }
        end

        def shell_init
          return nil if @shell_initialized
          result = execute(Powershell.shell_init)
          if result.exit_code != 0
            raise BaseError.new("Could not initialize shell: #{result.stderr.string}", "SHELL_INIT_ERROR")
          end
          @shell_initialized = true
        end

        def execute(command)
          result_output = Bolt::Node::Output.new

          @logger.debug { "Executing command: #{command}" }

          output = @session.run(command) do |stdout, stderr|
            result_output.stdout << stdout
            @logger.debug { "stdout: #{stdout}" }
            result_output.stderr << stderr
            @logger.debug { "stderr: #{stderr}" }
          end
          result_output.exit_code = output.exitcode
          if output.exitcode.zero?
            @logger.debug { "Command returned successfully" }
          else
            @logger.info { "Command failed with exit code #{output.exitcode}" }
          end
          result_output
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def execute_process(path = '', arguments = [], stdin = nil)
          execute(Powershell.execute_process(path, arguments, stdin))
        end

        def mkdirs(dirs)
          result = execute(Powershell.mkdirs(dirs))
          if result.exit_code != 0
            message = "Could not create directories: #{result.stderr}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def write_remote_file(source, destination)
          if target.options['file-protocol'] == 'smb'
            write_remote_file_smb(source, destination)
          else
            write_remote_file_winrm(source, destination)
          end
        end

        def write_remote_file_winrm(source, destination)
          fs = ::WinRM::FS::FileManager.new(@connection)
          fs.upload(source, destination)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def write_remote_file_smb(source, destination)
          # lazy-load expensive gem code
          require 'ruby_smb'

          win_dest = destination.tr('/', '\\')
          if (md = win_dest.match(/^([a-z]):\\(.*)/i))
            # if drive, use admin share for that drive, so path is '\\host\C$'
            path = "\\\\#{@target.host}\\#{md[1]}$"
            dest = md[2]
          elsif (md = win_dest.match(/^(\\\\[^\\]+\\[^\\]+)\\(.*)/))
            # if unc, path is '\\host\share'
            path = md[1]
            dest = md[2]
          else
            raise ArgumentError, "Unknown destination '#{destination}'"
          end

          client = smb_client_login
          tree = client.tree_connect(path)
          begin
            write_remote_file_smb_recursive(tree, source, dest)
          ensure
            tree.disconnect!
          end
        rescue ::RubySMB::Error::UnexpectedStatusCode => e
          raise Bolt::Node::FileError.new("SMB Error: #{e.message}", 'WRITE_ERROR')
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def make_tempdir
          find_parent = target.options['tmpdir'] ? "\"#{target.options['tmpdir']}\"" : '[System.IO.Path]::GetTempPath()'
          result = execute(Powershell.make_tempdir(find_parent))
          if result.exit_code != 0
            raise Bolt::Node::FileError.new("Could not make tempdir: #{result.stderr}", 'TEMPDIR_ERROR')
          end
          result.stdout.string.chomp
        end

        def with_remote_tempdir
          dir = make_tempdir
          yield dir
        ensure
          execute(Powershell.rmdir(dir))
        end

        def validate_extensions(ext)
          unless @extensions.include?(ext)
            raise Bolt::Node::FileError.new("File extension #{ext} is not enabled, "\
                                "to run it please add to 'winrm: extensions'", 'FILETYPE_ERROR')
          end
        end

        def write_remote_executable(dir, file, filename = nil)
          filename ||= File.basename(file)
          validate_extensions(File.extname(filename))
          remote_path = "#{dir}\\#{filename}"
          write_remote_file(file, remote_path)
          remote_path
        end

        def write_executable_from_content(dir, content, filename)
          validate_extensions(File.extname(filename))
          remote_path = "#{dir}\\#{filename}"
          write_remote_file(content, remote_path)
          remote_path
        end

        private

        def smb_client_login
          return @client if @client

          dispatcher = RubySMB::Dispatcher::Socket.new(smb_socket_connect)
          @client = RubySMB::Client.new(dispatcher, smb1: false, smb2: true, username: @user, password: target.password)
          status = @client.login
          case status
          when WindowsError::NTStatus::STATUS_SUCCESS
            @logger.debug { "Connected to #{@client.dns_host_name}" }
          when WindowsError::NTStatus::STATUS_LOGON_FAILURE
            raise Bolt::Node::ConnectError.new(
              "SMB authentication failed for #{target.host}",
              'AUTH_ERROR'
            )
          else
            raise Bolt::Node::ConnectError.new(
              "Failed to connect to #{target.host} using SMB: #{status.description}",
              'CONNECT_ERROR'
            )
          end

          @client
        end

        SMB_PORT = 445

        def smb_socket_connect
          # It's lame that TCPSocket doesn't take a connect timeout
          # Using Timeout.timeout is bad, but is done elsewhere...
          Timeout.timeout(target.options['connect-timeout']) do
            TCPSocket.new(target.host, target.options['smb-port'] || SMB_PORT)
          end
        rescue Errno::ECONNREFUSED => e
          # handle this to prevent obscuring error message as SMB problem
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.host} using SMB: #{e.message}",
            'CONNECT_ERROR'
          )
        rescue Timeout::Error
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{target.host}",
            'CONNECT_ERROR'
          )
        end

        def write_remote_file_smb_recursive(tree, source, dest)
          if Dir.exist?(source)
            tree.open_directory(directory: dest, write: true, disposition: ::RubySMB::Dispositions::FILE_OPEN_IF)

            (Dir.entries(source) - ['.', '..']).each do |child|
              child_dest = dest + '\\' + child
              write_remote_file_smb_recursive(tree, File.join(source, child), child_dest)
            end
            return
          end

          file = tree.open_file(filename: dest, write: true, disposition: ::RubySMB::Dispositions::FILE_OVERWRITE_IF)
          begin
            # `file` doesn't derive from IO, so can't use IO.copy_stream
            File.open(source, 'rb') do |f|
              pos = 0
              while (buf = f.read(8 * 1024 * 1024))
                file.write(data: buf, offset: pos)
                pos += buf.length
              end
            end
          ensure
            file.close
          end
        end
      end
    end
  end
end
