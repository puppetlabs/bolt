require 'json'
require 'shellwords'
require 'net/ssh'
require 'net/sftp'
require 'bolt/node/result'

module Bolt
  class SSH < Node
    def self.initialize_transport(logger)
      require 'net/ssh/krb'
    rescue LoadError
      logger.debug {
        "Authentication method 'gssapi-with-mic' is not available"
      }
    end

    def connect
      options = {
        logger: @transport_logger,
        non_interactive: true
      }

      options[:port] = @port if @port
      options[:password] = @password if @password
      options[:verify_host_key] = if @insecure
                                    Net::SSH::Verifiers::Lenient.new
                                  else
                                    Net::SSH::Verifiers::Secure.new
                                  end

      @session = Net::SSH.start(@host, @user, options)
      @logger.debug { "Opened session" }
    rescue Net::SSH::AuthenticationFailed => e
      raise Bolt::Node::ConnectError.new(
        e.message,
        'AUTH_ERROR'
      )
    rescue Net::SSH::HostKeyError => e
      raise Bolt::Node::ConnectError.new(
        "Host key verification failed for #{@uri}: #{e.message}",
        'HOST_KEY_ERROR'
      )
    rescue StandardError => e
      raise Bolt::Node::ConnectError.new(
        "Failed to connect to #{@uri}: #{e.message}",
        'CONNECT_ERROR'
      )
    end

    def disconnect
      if @session && !@session.closed?
        @session.close
        @logger.debug { "Closed session" }
      end
    end

    def execute(command, sudoable: false, **options)
      result_output = Bolt::Node::ResultOutput.new
      status = {}
      use_sudo = sudoable && (@sudo || @run_as)
      sudo_prompt = '[sudo] Bolt needs to run as another user, password: '
      if use_sudo
        user_clause = if @run_as
                        "-u #{@run_as}"
                      else
                        ''
                      end
        command = "sudo -S #{user_clause} -p '#{sudo_prompt}' #{command}"
      end

      @logger.debug { "Executing: #{command}" }

      session_channel = @session.open_channel do |channel|
        # Request a pseudo tty
        channel.request_pty if @tty

        channel.exec(command) do |_, success|
          raise "could not execute command: #{command.inspect}" unless success

          channel.on_data do |_, data|
            if use_sudo && data == sudo_prompt
              channel.send_data "#{@sudo_password}\n"
              channel.wait
            else
              result_output.stdout << data
            end
            @logger.debug { "stdout: #{data}" }
          end

          channel.on_extended_data do |_, _, data|
            if use_sudo && data == sudo_prompt
              channel.send_data "#{@sudo_password}\n"
              channel.wait
            else
              result_output.stderr << data
            end
            @logger.debug { "stderr: #{data}" }
          end

          channel.on_request("exit-status") do |_, data|
            status[:exit_code] = data.read_long
          end

          if options[:stdin]
            channel.send_data(options[:stdin])
            channel.eof!
          end
        end
      end
      session_channel.wait

      if status[:exit_code].zero?
        @logger.debug { "Command returned successfully" }
        Bolt::Node::Success.new(result_output.stdout.string, result_output)
      else
        @logger.info { "Command failed with exit code #{status[:exit_code]}" }
        Bolt::Node::Failure.new(status[:exit_code], result_output)
      end
    end

    def _upload(source, destination)
      Net::SFTP::Session.new(@session).connect! do |sftp|
        sftp.upload!(source, destination)
      end
      Bolt::Node::Success.new
    rescue StandardError => e
      Bolt::Node::ExceptionFailure.new(e)
    end

    def make_tempdir
      Bolt::Node::Success.new(@session.exec!('mktemp -d').chomp)
    rescue StandardError => e
      Bolt::Node::ExceptionFailure.new(e)
    end

    def with_remote_tempdir
      make_tempdir.then do |dir|
        (yield dir).ensure do
          execute("rm -rf '#{dir}'")
        end
      end
    end

    def with_remote_script(dir, file)
      remote_path = "#{dir}/#{File.basename(file)}"
      _upload(file, remote_path).then do
        execute("chmod u+x '#{remote_path}'")
      end.then do
        yield remote_path
      end
    end

    def with_remote_file(file)
      with_remote_tempdir do |dir|
        with_remote_script(dir, file) do |remote_path|
          yield remote_path
        end
      end
    end

    def make_wrapper_stringio(task_path, stdin)
      StringIO.new(<<-SCRIPT)
#!/bin/sh
'#{task_path}' <<EOF
#{stdin}
EOF
SCRIPT
    end

    def with_task_wrapper(remote_task, dir, stdin)
      wrapper = make_wrapper_stringio(remote_task, stdin)
      command = "#{dir}/wrapper.sh"
      _upload(wrapper, command).then do
        execute("chmod u+x '#{command}'")
      end.then do
        yield command
      end
    end

    def with_remote_task(task_file, stdin)
      with_remote_tempdir do |dir|
        with_remote_script(dir, task_file) do |remote_task|
          if stdin
            with_task_wrapper(remote_task, dir, stdin) do |command|
              yield command
            end
          else
            yield remote_task
          end
        end
      end
    end

    def _run_command(command)
      execute(command, sudoable: true)
    end

    def _run_script(script, arguments)
      @logger.info { "Running script '#{script}'" }
      @logger.debug { "arguments: #{arguments}" }

      with_remote_file(script) do |remote_path|
        execute("'#{remote_path}' #{Shellwords.join(arguments)}",
                sudoable: true)
      end
    end

    def _run_task(task, input_method, arguments)
      export_args = {}
      stdin = nil

      @logger.info { "Running task '#{task}'" }
      @logger.debug { "arguments: #{arguments}\ninput_method: #{input_method}" }

      if STDIN_METHODS.include?(input_method)
        stdin = JSON.dump(arguments)
      end

      if ENVIRONMENT_METHODS.include?(input_method)
        export_args = arguments.map do |env, val|
          "PT_#{env}='#{val}'"
        end.join(' ')
      end

      with_remote_task(task, stdin) do |remote_path|
        command = if export_args.empty?
                    "'#{remote_path}'"
                  else
                    "#{export_args} '#{remote_path}'"
                  end
        execute(command, sudoable: true)
      end
    end
  end
end
