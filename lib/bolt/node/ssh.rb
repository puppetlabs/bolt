require 'json'
require 'shellwords'
require 'net/ssh'
require 'net/sftp'
require 'bolt/node/output'

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
      result_output = Bolt::Node::Output.new
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
    end

    def _upload(source, destination)
      write_remote_file(source, destination)
      Bolt::Result.new
    rescue StandardError => e
      Bolt::Result.from_exception(e)
    end

    def write_remote_file(source, destination)
      conn = Net::SFTP::Session.new(@session).connect!
      # This provides a slighter better error for sftp misconfiguration
      raise "SFTP connection closed before #{destination} could be written" unless conn.open?
      conn.upload!(source, destination)
    rescue StandardError => e
      raise FileError.new(e.message, 'WRITE_ERROR')
    end

    def make_tempdir
      result = execute('mktemp -d')
      if result.exit_code != 0
        raise FileError.new("Could not make tempdir: #{result.stderr.string}", 'TEMPDIR_ERROR')
      end
      result.stdout.string.chomp
    end

    def with_remote_tempdir
      dir = make_tempdir
      begin
        yield dir
      ensure
        output =  execute("rm -rf '#{dir}'")
        if output.exit_code != 0
          logger.warn("Failed to clean up tempdir '#{dir}': #{output.stderr.string}")
        end
      end
    end

    def with_remote_script(dir, file)
      remote_path = "#{dir}/#{File.basename(file)}"
      write_remote_file(file, remote_path)
      make_executable(remote_path)
      yield remote_path
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

    def make_executable(path)
      result = execute("chmod u+x '#{path}'")
      if result.exit_code != 0
        raise FileError.new("Could not make file '#{path}' executable: #{result.stderr.string}", 'CHMOD_ERROR')
      end
    end

    def with_task_wrapper(remote_task, dir, stdin)
      wrapper = make_wrapper_stringio(remote_task, stdin)
      command = "#{dir}/wrapper.sh"
      write_remote_file(wrapper, command)
      make_executable(command)
      yield command
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
      output = execute(command, sudoable: true)
      Bolt::CommandResult.from_output(output)
    # TODO: We should be able to rely on the excutor for this but it will mean
    # a test refactor
    rescue StandardError => e
      Bolt::Result.from_exception(e)
    end

    def _run_script(script, arguments)
      @logger.info { "Running script '#{script}'" }
      @logger.debug { "arguments: #{arguments}" }

      with_remote_file(script) do |remote_path|
        output = execute("'#{remote_path}' #{Shellwords.join(arguments)}",
                         sudoable: true)
        Bolt::CommandResult.from_output(output)
      end
    # TODO: We should be able to rely on the excutor for this but it will mean
    # a test refactor
    rescue StandardError => e
      Bolt::Result.from_exception(e)
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
        output = execute(command, sudoable: true)
        Bolt::TaskResult.from_output(output)
      end
    # TODO: We should be able to rely on the excutor for this but it will mean
    # a test refactor
    rescue StandardError => e
      Bolt::Result.from_exception(e)
    end
  end
end
