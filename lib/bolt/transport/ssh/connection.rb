# frozen_string_literal: true

require 'logging'
require 'shellwords'
require 'bolt/node/errors'
require 'bolt/node/output'
require 'bolt/util'
require 'net/ssh/proxy/jump'

module Bolt
  module Transport
    class SSH < Base
      class Connection
        class RemoteTempdir
          def initialize(node, path)
            @node = node
            @owner = node.user
            @path = path
            @logger = node.logger
          end

          def to_s
            @path
          end

          def mkdirs(subdirs)
            abs_subdirs = subdirs.map { |subdir| File.join(@path, subdir) }
            result = @node.execute(['mkdir', '-p'] + abs_subdirs)
            if result.exit_code != 0
              message = "Could not create subdirectories in '#{@path}': #{result.stderr.string}"
              raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
            end
          end

          def chown(owner)
            return if owner.nil? || owner == @owner

            result = @node.execute(['id', '-g', owner])
            if result.exit_code != 0
              message = "Could not identify group of user #{owner}: #{result.stderr.string}"
              raise Bolt::Node::FileError.new(message, 'ID_ERROR')
            end
            group = result.stdout.string.chomp

            # Chown can only be run by root.
            result = @node.execute(['chown', '-R', "#{owner}:#{group}", @path], sudoable: true, run_as: 'root')
            if result.exit_code != 0
              message = "Could not change owner of '#{@path}' to #{owner}: #{result.stderr.string}"
              raise Bolt::Node::FileError.new(message, 'CHOWN_ERROR')
            end

            # File ownership successfully changed, record the new owner.
            @owner = owner
          end

          def delete
            result = @node.execute(['rm', '-rf', @path], sudoable: true, run_as: @owner)
            if result.exit_code != 0
              @logger.warn("Failed to clean up tempdir '#{@path}': #{result.stderr.string}")
            end
          end
        end

        attr_reader :logger, :user, :target
        attr_writer :run_as

        def initialize(target, transport_logger, load_config = true)
          @target = target
          @load_config = load_config

          ssh_user = load_config ? Net::SSH::Config.for(target.host)[:user] : nil
          @user = @target.user || ssh_user || Etc.getlogin
          @run_as = nil

          @logger = Logging.logger[@target.host]
          @transport_logger = transport_logger
        end

        PAGEANT_NAME = "Pageant\0".encode(Encoding::UTF_16LE)

        def connect
          options = {
            logger: @transport_logger,
            non_interactive: true
          }

          if (key = target.options['private-key'])
            if key.instance_of?(String)
              options[:keys] = key
            else
              options[:key_data] = [key['key-data']]
            end
          end

          options[:port] = target.port if target.port
          options[:password] = target.password if target.password
          # Support both net-ssh 4 and 5. We use 5 in packaging, but Beaker pins to 4 so we
          # want the gem to be compatible with version 4.
          options[:verify_host_key] = if target.options['host-key-check']
                                        if defined?(Net::SSH::Verifiers::Always)
                                          Net::SSH::Verifiers::Always.new
                                        else
                                          Net::SSH::Verifiers::Secure.new
                                        end
                                      elsif defined?(Net::SSH::Verifiers::Never)
                                        Net::SSH::Verifiers::Never.new
                                      else
                                        Net::SSH::Verifiers::Null.new
                                      end
          options[:timeout] = target.options['connect-timeout'] if target.options['connect-timeout']

          options[:proxy] = Net::SSH::Proxy::Jump.new(target.options['proxyjump']) if target.options['proxyjump']

          # This option was to address discrepency betwen net-ssh host-key-check and ssh(1)
          # For the net-ssh 5.x series it defaults to true, in 6.x it will default to false, and will be removed in 7.x
          # https://github.com/net-ssh/net-ssh/pull/663#issuecomment-469979931
          options[:check_host_ip] = false if Net::SSH::VALID_OPTIONS.include?(:check_host_ip)

          if @load_config
            # Mirroring:
            # https://github.com/net-ssh/net-ssh/blob/master/lib/net/ssh/authentication/agent.rb#L80
            # https://github.com/net-ssh/net-ssh/blob/master/lib/net/ssh/authentication/pageant.rb#L403
            if defined?(UNIXSocket) && UNIXSocket
              if ENV['SSH_AUTH_SOCK'].to_s.empty?
                @logger.debug { "Disabling use_agent in net-ssh: ssh-agent is not available" }
                options[:use_agent] = false
              end
            elsif Bolt::Util.windows?
              require 'Win32API' # case matters in this require!
              # https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-findwindoww
              @find_window ||= Win32API.new('user32', 'FindWindowW', %w[P P], 'L')
              if @find_window.call(nil, PAGEANT_NAME).to_i == 0
                @logger.debug { "Disabling use_agent in net-ssh: pageant process not running" }
                options[:use_agent] = false
              end
            end
          else
            # Disable ssh config and ssh-agent if requested via load_config
            options[:config] = false
            options[:use_agent] = false
          end

          @session = Net::SSH.start(target.host, @user, options)
          @logger.debug { "Opened session" }
        rescue Net::SSH::AuthenticationFailed => e
          raise Bolt::Node::ConnectError.new(
            e.message,
            'AUTH_ERROR'
          )
        rescue Net::SSH::HostKeyError => e
          raise Bolt::Node::ConnectError.new(
            "Host key verification failed for #{target.uri}: #{e.message}",
            'HOST_KEY_ERROR'
          )
        rescue Net::SSH::ConnectionTimeout
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{target.uri}",
            'CONNECT_ERROR'
          )
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.uri}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def disconnect
          if @session && !@session.closed?
            @session.close
            @logger.debug { "Closed session" }
          end
        end

        # This method allows the @run_as variable to be used as a per-operation
        # override for the user to run as. When @run_as is unset, the user
        # specified on the target will be used.
        def run_as
          @run_as || target.options['run-as']
        end

        # Run as the specified user for the duration of the block.
        def running_as(user)
          @run_as = user
          yield
        ensure
          @run_as = nil
        end

        def sudo_prompt
          '[sudo] Bolt needs to run as another user, password: '
        end

        def handled_sudo(channel, data)
          if data.lines.include?(sudo_prompt)
            if target.options['sudo-password']
              channel.send_data "#{target.options['sudo-password']}\n"
              channel.wait
              return true
            else
              # Cancel the sudo prompt to prevent later commands getting stuck
              channel.close
              raise Bolt::Node::EscalateError.new(
                "Sudo password for user #{@user} was not provided for #{target.uri}",
                'NO_PASSWORD'
              )
            end
          elsif data =~ /^#{@user} is not in the sudoers file\./
            @logger.debug { data }
            raise Bolt::Node::EscalateError.new(
              "User #{@user} does not have sudo permission on #{target.uri}",
              'SUDO_DENIED'
            )
          elsif data =~ /^Sorry, try again\./
            @logger.debug { data }
            raise Bolt::Node::EscalateError.new(
              "Sudo password for user #{@user} not recognized on #{target.uri}",
              'BAD_PASSWORD'
            )
          end
          false
        end

        def execute(command, sudoable: false, **options)
          result_output = Bolt::Node::Output.new
          run_as = options[:run_as] || self.run_as
          escalate = sudoable && run_as && @user != run_as
          use_sudo = escalate && @target.options['run-as-command'].nil?

          if options[:interpreter]
            command.is_a?(Array) ? command.unshift(options[:interpreter]) : [options[:interpreter], command]
          end

          command_str = command.is_a?(String) ? command : Shellwords.shelljoin(command)
          if escalate
            if use_sudo
              sudo_flags = ["sudo", "-S", "-u", run_as, "-p", sudo_prompt]
              sudo_flags += ["-E"] if options[:environment]
              sudo_str = Shellwords.shelljoin(sudo_flags)
              command_str = "#{sudo_str} #{command_str}"
            else
              run_as_str = Shellwords.shelljoin(@target.options['run-as-command'] + [run_as])
              command_str = "#{run_as_str} #{command_str}"
            end
          end

          # Including the environment declarations in the shelljoin will escape
          # the = sign, so we have to handle them separately.
          if options[:environment]
            env_decls = options[:environment].map do |env, val|
              "#{env}=#{Shellwords.shellescape(val)}"
            end
            command_str = "#{env_decls.join(' ')} #{command_str}"
          end

          @logger.debug { "Executing: #{command_str}" }

          session_channel = @session.open_channel do |channel|
            # Request a pseudo tty
            channel.request_pty if target.options['tty']

            channel.exec(command_str) do |_, success|
              unless success
                raise Bolt::Node::ConnectError.new(
                  "Could not execute command: #{command_str.inspect}",
                  'EXEC_ERROR'
                )
              end

              channel.on_data do |_, data|
                unless use_sudo && handled_sudo(channel, data)
                  result_output.stdout << data
                end
                @logger.debug { "stdout: #{data.strip}" }
              end

              channel.on_extended_data do |_, _, data|
                unless use_sudo && handled_sudo(channel, data)
                  result_output.stderr << data
                end
                @logger.debug { "stderr: #{data.strip}" }
              end

              channel.on_request("exit-status") do |_, data|
                result_output.exit_code = data.read_long
              end

              if options[:stdin]
                channel.send_data(options[:stdin])
                channel.eof!
              end
            end
          end
          session_channel.wait

          if result_output.exit_code == 0
            @logger.debug { "Command returned successfully" }
          else
            @logger.info { "Command failed with exit code #{result_output.exit_code}" }
          end
          result_output
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def write_remote_file(source, destination)
          @session.scp.upload!(source, destination, recursive: true)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def make_tempdir
          tmpdir = target.options.fetch('tmpdir', '/tmp')
          tmppath = "#{tmpdir}/#{SecureRandom.uuid}"
          command = ['mkdir', '-m', 700, tmppath]

          result = execute(command)
          if result.exit_code != 0
            raise Bolt::Node::FileError.new("Could not make tempdir: #{result.stderr.string}", 'TEMPDIR_ERROR')
          end
          path = tmppath || result.stdout.string.chomp
          RemoteTempdir.new(self, path)
        end

        # A helper to create and delete a tempdir on the remote system. Yields the
        # directory name.
        def with_remote_tempdir
          dir = make_tempdir
          yield dir
        ensure
          dir&.delete
        end

        def write_remote_executable(dir, file, filename = nil)
          filename ||= File.basename(file)
          remote_path = File.join(dir.to_s, filename)
          write_remote_file(file, remote_path)
          make_executable(remote_path)
          remote_path
        end

        def write_executable_from_content(dest, content, filename)
          remote_path = File.join(dest.to_s, filename)
          @session.scp.upload!(StringIO.new(content), remote_path)
          make_executable(remote_path)
          remote_path
        end

        def make_executable(path)
          result = execute(['chmod', 'u+x', path])
          if result.exit_code != 0
            message = "Could not make file '#{path}' executable: #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'CHMOD_ERROR')
          end
        end
      end
    end
  end
end
