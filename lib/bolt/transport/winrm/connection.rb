# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/node/output'

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

          @logger = Logging.logger[@target.safe_name]
          logger.debug("Initializing winrm connection to #{@target.safe_name}")
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
            theres_your_problem = "\nIs the remote host using a self-signed SSL "\
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

        def execute(command)
          @logger.debug { "Executing command: #{command}" }

          inp = StringIO.new
          # This transport doesn't accept stdin, so close the stream to ensure
          # it will fail if the shell attempts to provide stdin
          inp.close

          out_rd, out_wr = IO.pipe('UTF-8')
          err_rd, err_wr = IO.pipe('UTF-8')
          th = Thread.new do
            result = @session.run(command)
            out_wr << result.stdout
            err_wr << result.stderr
            out_wr.close
            err_wr.close
            result.exitcode
          end

          [inp, out_rd, err_rd, th]
        rescue Errno::EMFILE => e
          msg = "#{e.message}. This may be resolved by increasing your user limit "\
            "with 'ulimit -n 1024'. See https://puppet.com/docs/bolt/latest/bolt_known_issues.html for details."
          raise Bolt::Error.new(msg, 'bolt/too-many-files')
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def copy_file(source, destination)
          @logger.debug { "Uploading #{source}, to #{destination}" }
          if target.options['file-protocol'] == 'smb'
            copy_file_smb(source, destination)
          else
            copy_file_winrm(source, destination)
          end
        end

        def copy_file_winrm(source, destination)
          fs = ::WinRM::FS::FileManager.new(@connection)
          fs.upload(source, destination)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def copy_file_smb(source, destination)
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
            copy_file_smb_recursive(tree, source, dest)
          ensure
            tree.disconnect!
          end
        rescue ::RubySMB::Error::UnexpectedStatusCode => e
          raise Bolt::Node::FileError.new("SMB Error: #{e.message}", 'WRITE_ERROR')
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def shell
          @shell ||= Bolt::Shell::Powershell.new(target, self)
        end

        def max_command_length
          nil
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
            "Failed to connect to #{target.safe_name} using SMB: #{e.message}",
            'CONNECT_ERROR'
          )
        rescue Timeout::Error
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{target.safe_name}",
            'CONNECT_ERROR'
          )
        end

        def copy_file_smb_recursive(tree, source, dest)
          if Dir.exist?(source)
            tree.open_directory(directory: dest, write: true, disposition: ::RubySMB::Dispositions::FILE_OPEN_IF)

            Dir.children(source).each do |child|
              child_dest = dest + '\\' + child
              copy_file_smb_recursive(tree, File.join(source, child), child_dest)
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
