# frozen_string_literal: true

require_relative '../../../bolt/node/errors'
require_relative '../../../bolt/node/output'

module Bolt
  module Transport
    class WinRM < Simple
      class Connection
        attr_reader :logger, :target

        def initialize(target, transport_logger)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host
          @target = target

          default_port = target.options['ssl'] ? HTTPS_PORT : HTTP_PORT
          @port = @target.port || default_port
          @user = @target.user
          # Build set of extensions from extensions config as well as interpreters

          @logger = Bolt::Logger.logger(@target.safe_name)
          logger.trace("Initializing winrm connection to #{@target.safe_name}")
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

          transport = :kerberos if target.options['realm']
          endpoint = "#{scheme}://#{target.host}:#{@port}/wsman"
          cacert = target.options['cacert'] && target.options['ssl'] ? File.expand_path(target.options['cacert']) : nil
          options = { endpoint: endpoint,
                      # https://github.com/WinRb/WinRM/issues/270
                      user: target.options['realm'] ? 'dummy' : @user,
                      password: target.options['realm'] ? 'dummy' : target.password,
                      retry_limit: 1,
                      transport: transport,
                      basic_auth_only: target.options['basic-auth-only'],
                      ca_trust_path: cacert,
                      realm: target.options['realm'],
                      no_ssl_peer_verification: !target.options['ssl-verify'] }

          Timeout.timeout(target.options['connect-timeout']) do
            @connection = ::WinRM::Connection.new(options)
            @connection.logger = @transport_logger

            @connection.shell(:powershell) do |session|
              session.run('$PSVersionTable.PSVersion')
            end

            @logger.trace { "Opened connection" }
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
            theres_your_problem = "\nIs the remote host using a self-signed SSL " \
                                  "certificate? Use --no-ssl-verify to disable " \
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
          @client&.disconnect!
          @logger.trace { "Closed connection" }
        end

        def execute(command)
          @logger.trace { "Executing command: #{command}" }

          inp = StringIO.new
          # This transport doesn't accept stdin, so close the stream to ensure
          # it will fail if the shell attempts to provide stdin
          inp.close

          out_rd, out_wr = IO.pipe('UTF-8')
          err_rd, err_wr = IO.pipe('UTF-8')
          th = Thread.new do
            # By default, any exception raised in a thread will be reported to
            # stderr as a stacktrace. Since we know these errors are going to
            # propagate to the main thread via the shell, there's no chance
            # they will be unhandled, so the default stack trace is unneeded.
            Thread.current.report_on_exception = false

            # Open a new shell instance for each command executed. PowerShell is
            # unable to unload any DLLs loaded when running a PowerShell script
            # or task from the same shell instance they were loaded in, which
            # prevents Bolt from cleaning up the temp directory successfully.
            # Using a new PowerShell instance avoids this limitation.
            @connection.shell(:powershell) do |session|
              result = session.run(command)
              out_wr << result.stdout
              err_wr << result.stderr
              result.exitcode
            end
          ensure
            # Close the streams to avoid the caller deadlocking
            out_wr.close
            err_wr.close
          end

          [inp, out_rd, err_rd, th]
        rescue Errno::EMFILE => e
          msg = "#{e.message}. This might be resolved by increasing your user limit " \
                "with 'ulimit -n 1024'. See https://puppet.com/docs/bolt/latest/bolt_known_issues.html for details."
          raise Bolt::Error.new(msg, 'bolt/too-many-files')
        rescue StandardError
          @logger.trace { "Command aborted" }
          raise
        end

        def upload_file(source, destination)
          @logger.trace { "Uploading #{source} to #{destination}" }
          if target.options['file-protocol'] == 'smb'
            upload_file_smb(source, destination)
          else
            upload_file_winrm(source, destination)
          end
        end

        def upload_file_winrm(source, destination)
          fs = ::WinRM::FS::FileManager.new(@connection)
          fs.upload(source, destination)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def upload_file_smb(source, destination)
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
            upload_file_smb_recursive(tree, source, dest)
          ensure
            tree.disconnect!
          end
        rescue ::RubySMB::Error::UnexpectedStatusCode => e
          raise Bolt::Node::FileError.new("SMB Error: #{e.message}", 'WRITE_ERROR')
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def download_file(source, destination, download)
          @logger.trace { "Downloading #{source} to #{destination}" }
          if target.options['file-protocol'] == 'smb'
            download_file_smb(source, destination)
          else
            download_file_winrm(source, destination, download)
          end
        end

        def download_file_winrm(source, destination, download)
          # The winrm gem doesn't create the destination directory if it's missing,
          # so create it here
          FileUtils.mkdir_p(destination)
          fs = ::WinRM::FS::FileManager.new(@connection)
          # params: source, destination, chunksize, first
          # first needs to be set to false, otherwise if the source is a directory it
          # will be nested inside a directory with the same name
          fs.download(source, download, 1024 * 1024, false)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def download_file_smb(source, destination)
          # lazy-load expensive gem code
          require 'ruby_smb'

          win_source = source.tr('/', '\\')
          if (md = win_source.match(/^([a-z]):\\(.*)/i))
            # if drive, use admin share for that drive, so path is '\\host\C$'
            path = "\\\\#{@target.host}\\#{md[1]}$"
            src  = md[2]
          elsif (md = win_source.match(/^(\\\\[^\\]+\\[^\\]+)\\(.*)/))
            # if unc, path is '\\host\share'
            path = md[1]
            src  = md[2]
          else
            raise ArgumentError, "Unknown source '#{source}'"
          end

          client = smb_client_login
          tree = client.tree_connect(path)

          begin
            # Make sure the root download directory for the target exists
            FileUtils.mkdir_p(destination)
            download_file_smb_recursive(tree, src, destination)
          ensure
            tree.disconnect!
          end
        rescue ::RubySMB::Error::UnexpectedStatusCode => e
          raise Bolt::Node::FileError.new("SMB Error: #{e.message}", 'DOWNLOAD_ERROR')
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'DOWNLOAD_ERROR')
        end

        def shell
          @shell ||= Bolt::Shell::Powershell.new(target, self)
        end

        def max_command_length
          nil
        end

        SMB_PORT = 445

        private

        def smb_client_login
          return @client if @client

          dispatcher = RubySMB::Dispatcher::Socket.new(smb_socket_connect)
          @client = RubySMB::Client.new(dispatcher, smb1: false, smb2: true, username: @user, password: target.password)
          status = @client.login
          case status
          when WindowsError::NTStatus::STATUS_SUCCESS
            @logger.trace { "Connected to #{@client.dns_host_name}" }
          when WindowsError::NTStatus::STATUS_LOGON_FAILURE
            raise Bolt::Node::ConnectError.new(
              "SMB authentication failed for #{target.safe_name}",
              'AUTH_ERROR'
            )
          else
            raise Bolt::Node::ConnectError.new(
              "Failed to connect to #{target.safe_name} using SMB: #{status.description}",
              'CONNECT_ERROR'
            )
          end

          @client
        end

        def smb_socket_connect
          # It's lame that TCPSocket doesn't take a connect timeout
          # Using Timeout.timeout is bad, but is done elsewhere...
          Timeout.timeout(target.options['connect-timeout']) do
            TCPSocket.new(target.host, target.options['smb-port'] || SMB_PORT)
          end
        rescue Errno::ECONNREFUSED => e
          # handle this to prevent obscuring error message as SMB problem
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.safe_name} using SMB: #{e.message}",
            'CONNECT_ERROR'
          )
        rescue Timeout::Error
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{target.safe_name}",
            'CONNECT_ERROR'
          )
        end

        def upload_file_smb_recursive(tree, source, dest)
          if Dir.exist?(source)
            tree.open_directory(directory: dest, write: true, disposition: ::RubySMB::Dispositions::FILE_OPEN_IF)

            Dir.children(source).each do |child|
              child_dest = dest + '\\' + child
              upload_file_smb_recursive(tree, File.join(source, child), child_dest)
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

        def download_file_smb_recursive(tree, source, destination)
          dest = File.expand_path(Bolt::Util.windows_basename(source), destination)

          # Check if the source is a directory by attempting to list its children.
          # If the source is a directory, create the directory on the host and then
          # recurse through the children.
          if (children = list_directory_children_smb(tree, source))
            FileUtils.mkdir_p(dest)

            children.each do |child|
              # File names are encoded UTF_16LE.
              filename = child.file_name.encode(Encoding::UTF_8)

              next if %w[. ..].include?(filename)

              src = source + '\\' + filename
              download_file_smb_recursive(tree, src, dest)
            end
          # If the source wasn't a directory and just returns 'STATUS_NOT_A_DIRECTORY, then
          # it is a file. Write it to the host.
          else
            begin
              file = tree.open_file(filename: source)
              data = file.read

              # Files may be encoded UTF_16LE
              data = data.encode(Encoding::UTF_8) if data.encoding == Encoding::UTF_16LE

              File.write(dest, data)
            ensure
              file.close
            end
          end
        end

        # Lists the children of a directory using rb_smb
        # Returns an array of RubySMB::Fscc::FileInformation::FileIdFullDirectoryInformation objects
        # if the source is a directory, or raises RubySMB::Error::UnexpectedStatusCode otherwise.
        def list_directory_children_smb(tree, source)
          tree.list(directory: source)
        rescue RubySMB::Error::UnexpectedStatusCode => e
          unless e.message == 'STATUS_NOT_A_DIRECTORY'
            raise e
          end
        end
      end
    end
  end
end
