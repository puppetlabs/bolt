require 'net/ssh'
require 'net/sftp'
require 'json'
require 'bolt/node/result'

module Bolt
  class SSH < Node
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
    rescue Net::SSH::HostKeyError => e
      raise Bolt::Node::ConnectError.new(
        "Host key verification failed for #{@uri}: #{e.message}",
        'HOST_KEY_ERROR'
      )
    end

    def disconnect
      if @session && !@session.closed?
        @session.close
        @logger.debug { "Closed session" }
      end
    end

    def execute(command, options = {})
      result_output = Bolt::Node::ResultOutput.new
      status = {}

      @logger.debug { "Executing: #{command}" }

      session_channel = @session.open_channel do |channel|
        # Request a pseudo tty
        channel.request_pty if @tty

        channel.exec(command) do |_, success|
          raise "could not execute command: #{command.inspect}" unless success

          channel.on_data do |_, data|
            result_output.stdout << data
            @logger.debug { "stdout: #{data}" }
          end

          channel.on_extended_data do |_, _, data|
            result_output.stderr << data
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

    def with_remote_file(file)
      remote_path = ''
      dir = ''
      result = nil

      make_tempdir.then do |value|
        dir = value
        remote_path = "#{dir}/#{File.basename(file)}"
        Bolt::Node::Success.new
      end.then do
        _upload(file, remote_path)
      end.then do
        execute("chmod u+x '#{remote_path}'")
      end.then do
        result = yield remote_path
      end.then do
        execute("rm -f '#{remote_path}'")
      end.then do
        execute("rmdir '#{dir}'")
        result
      end
    end

    def _run_command(command)
      execute(command)
    end

    def _run_script(script)
      @logger.info { "Running script '#{script}'" }
      with_remote_file(script) do |remote_path|
        execute("'#{remote_path}'")
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

      with_remote_file(task) do |remote_path|
        command = if export_args.empty?
                    "'#{remote_path}'"
                  else
                    "export #{export_args} && '#{remote_path}'"
                  end
        execute(command, stdin: stdin)
      end
    end
  end
end
