# frozen_string_literal: true

require 'logging'
require 'shellwords'
require 'bolt/node/errors'
require 'bolt/node/output'
require 'bolt/util'

module Bolt
  module Transport
    class SSH < Simple
      class Connection
        attr_reader :logger, :user, :target

        def initialize(target, transport_logger)
          # lazy-load expensive gem code
          require 'net/ssh'
          require 'net/ssh/proxy/jump'

          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host

          @target = target
          @load_config = target.options['load-config']

          ssh_config = @load_config ? Net::SSH::Config.for(target.host) : {}
          @user = @target.user || ssh_config[:user] || Etc.getlogin
          @strict_host_key_checking = ssh_config[:strict_host_key_checking]

          @logger = Logging.logger[@target.safe_name]
          @transport_logger = transport_logger
          @logger.debug("Initializing ssh connection to #{@target.safe_name}")

          if target.options['private-key']&.instance_of?(String)
            begin
              Bolt::Util.validate_file('ssh key', target.options['private-key'])
            rescue Bolt::FileError => e
              @logger.warn(e.msg)
            end
          end
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
          options[:verify_host_key] = if target.options['host-key-check'].nil?
                                        # Fall back to SSH behavior. This variable will only be set in net-ssh 5.3+.
                                        if @strict_host_key_checking.nil? || @strict_host_key_checking
                                          net_ssh_verifier(:always)
                                        else
                                          # SSH's behavior with StrictHostKeyChecking=no: adds new keys to known_hosts.
                                          # If known_hosts points to /dev/null, then equivalent to :never where it
                                          # accepts any key beacuse they're all new.
                                          net_ssh_verifier(:accept_new_or_tunnel_local)
                                        end
                                      elsif target.options['host-key-check']
                                        net_ssh_verifier(:always)
                                      else
                                        net_ssh_verifier(:never)
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
            "Host key verification failed for #{target.safe_name}: #{e.message}",
            'HOST_KEY_ERROR'
          )
        rescue Net::SSH::ConnectionTimeout
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{target.safe_name}",
            'CONNECT_ERROR'
          )
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def disconnect
          if @session && !@session.closed?
            begin
              Timeout.timeout(@target.options['disconnect-timeout']) { @session.close }
            rescue Timeout::Error
              @session.shutdown!
            end
            @logger.debug { "Closed session" }
          end
        end

        def execute(command_str, **options)
          result_output = Bolt::Node::Output.new
          # Including the environment declarations in the shelljoin will escape
          # the = sign, so we have to handle them separately.
          if options[:environment]
            env_decls = options[:environment].map do |env, val|
              "#{env}=#{Shellwords.shellescape(val)}"
            end
            command_str = "#{env_decls.join(' ')} #{command_str}"
          end

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
                result_output.stdout << data
                @logger.debug { "stdout: #{data.strip}" }
              end

              channel.on_extended_data do |_, _, data|
                result_output.stderr << data
                @logger.debug { "stderr: #{data.strip}" }
              end

              channel.on_request("exit-status") do |_, data|
                result_output.exit_code = data.read_long
              end
              # A wrapper is used to direct stdin when elevating privilage or using tty
              if options[:stdin]
                channel.send_data(options[:stdin])
                channel.eof!
              end
            end
          end
          session_channel.wait

          result_output
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def copy_file(source, destination)
          # Do not log wrapper script content
          @logger.debug { "Uploading #{source}, to #{destination}" } unless source.is_a?(StringIO)
          @session.scp.upload!(source, destination, recursive: true)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        # This handles renaming Net::SSH verifiers between version 4.x and 5.x
        # of the gem
        def net_ssh_verifier(verifier)
          case verifier
          when :always
            if defined?(Net::SSH::Verifiers::Always)
              Net::SSH::Verifiers::Always.new
            else
              Net::SSH::Verifiers::Secure.new
            end
          when :never
            if defined?(Net::SSH::Verifiers::Never)
              Net::SSH::Verifiers::Never.new
            else
              Net::SSH::Verifiers::Null.new
            end
          when :accept_new_or_tunnel_local
            if defined?(Net::SSH::Verifiers::AcceptNewOrLocalTunnel)
              Net::SSH::Verifiers::AcceptNewOrLocalTunnel.new
            else
              Net::SSH::Verifiers::Lenient.new
            end
          end
        end

        def shell
          # SSH only supports bash for now. Later, this will detect the correct shell.
          @shell ||= Bolt::Shell::Bash.new(target, self)
        end
      end
    end
  end
end
