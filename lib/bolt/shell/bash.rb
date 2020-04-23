# frozen_string_literal: true

require 'bolt/shell/bash/tmpdir'
require 'shellwords'

module Bolt
  class Shell
    class Bash < Shell
      CHUNK_SIZE = 4096

      def initialize(target, conn)
        super

        @run_as = nil

        @sudo_id = SecureRandom.uuid
        @sudo_password = @target.options['sudo-password'] || @target.password
      end

      def provided_features
        ['shell']
      end

      def run_command(command, options = {})
        running_as(options[:run_as]) do
          output = execute(command, sudoable: true)
          Bolt::Result.for_command(target,
                                   output.stdout.string,
                                   output.stderr.string,
                                   output.exit_code,
                                   'command', command)
        end
      end

      def upload(source, destination, options = {})
        running_as(options[:run_as]) do
          with_tempdir do |dir|
            basename = File.basename(destination)
            tmpfile = File.join(dir.to_s, basename)
            conn.copy_file(source, tmpfile)
            # pass over file ownership if we're using run-as to be a different user
            dir.chown(run_as)
            result = execute(['mv', '-f', tmpfile, destination], sudoable: true)
            if result.exit_code != 0
              message = "Could not move temporary file '#{tmpfile}' to #{destination}: #{result.stderr.string}"
              raise Bolt::Node::FileError.new(message, 'MV_ERROR')
            end
          end
          Bolt::Result.for_upload(target, source, destination)
        end
      end

      def run_script(script, arguments, options = {})
        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)

        running_as(options[:run_as]) do
          with_tempdir do |dir|
            path = write_executable(dir.to_s, script)
            dir.chown(run_as)
            output = execute([path, *arguments], sudoable: true)
            Bolt::Result.for_command(target,
                                     output.stdout.string,
                                     output.stderr.string,
                                     output.exit_code,
                                     'script', script)
          end
        end
      end

      def run_task(task, arguments, options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']

        running_as(options[:run_as]) do
          stdin, output = nil
          execute_options = {}
          execute_options[:interpreter] = select_interpreter(executable, target.options['interpreters'])
          interpreter_debug = if execute_options[:interpreter]
                                " using '#{execute_options[:interpreter]}' interpreter"
                              end
          # log the arguments with sensitive data redacted, do NOT log unwrapped_arguments
          logger.debug("Running '#{executable}' with #{arguments.to_json}#{interpreter_debug}")
          # unpack any Sensitive data
          arguments = unwrap_sensitive_args(arguments)

          with_tempdir do |dir|
            if extra_files.empty?
              task_dir = dir
            else
              # TODO: optimize upload of directories
              arguments['_installdir'] = dir.to_s
              task_dir = File.join(dir.to_s, task.tasks_dir)
              dir.mkdirs([task.tasks_dir] + extra_files.map { |file| File.dirname(file['name']) })
              extra_files.each do |file|
                conn.copy_file(file['path'], File.join(dir.to_s, file['name']))
              end
            end

            if Bolt::Task::STDIN_METHODS.include?(input_method)
              stdin = JSON.dump(arguments)
            end

            if Bolt::Task::ENVIRONMENT_METHODS.include?(input_method)
              execute_options[:environment] = envify_params(arguments)
            end

            remote_task_path = write_executable(task_dir, executable)

            # Avoid the horrors of passing data on stdin via a tty on multiple platforms
            # by writing a wrapper script that directs stdin to the task.
            if stdin && target.options['tty']
              wrapper = make_wrapper_stringio(remote_task_path, stdin, execute_options[:interpreter])
              execute_options.delete(:interpreter)
              execute_options[:wrapper] = true
              remote_task_path = write_executable(dir, wrapper, 'wrapper.sh')
            end

            dir.chown(run_as)

            execute_options[:stdin] = stdin
            execute_options[:sudoable] = true if run_as
            output = execute(remote_task_path, execute_options)
          end
          Bolt::Result.for_task(target, output.stdout.string,
                                output.stderr.string,
                                output.exit_code,
                                task.name)
        end
      end

      # If prompted for sudo password, send password to stdin and return an
      # empty string. Otherwise, check for sudo errors and raise Bolt error.
      # If sudo_id is detected, that means the task needs to have stdin written.
      # If error is not sudo-related, return the stderr string to be added to
      # node output
      def handle_sudo(stdin, err, sudo_stdin)
        if err.include?(sudo_prompt)
          # A wild sudo prompt has appeared!
          if @sudo_password
            stdin.write("#{@sudo_password}\n")
            ''
          else
            raise Bolt::Node::EscalateError.new(
              "Sudo password for user #{conn.user} was not provided for #{target}",
              'NO_PASSWORD'
            )
          end
        elsif err =~ /^#{@sudo_id}/
          if sudo_stdin
            stdin.write("#{sudo_stdin}\n")
            stdin.close
          end
          ''
        else
          handle_sudo_errors(err)
        end
      end

      # See if there's a sudo prompt in the output
      # If not, return the output
      def check_sudo(out, inp, stdin)
        buffer = out.readpartial(CHUNK_SIZE)
        # Split on newlines, including the newline
        lines = buffer.split(/(?<=[\n])/)
        # handle_sudo will return the line if it is not a sudo prompt or error
        lines.map! { |line| handle_sudo(inp, line, stdin) }
        lines.join("")
      # If stream has reached EOF, no password prompt is expected
      # return an empty string
      rescue EOFError
        ''
      end

      def handle_sudo_errors(err)
        if err =~ /^#{conn.user} is not in the sudoers file\./
          @logger.debug { err }
          raise Bolt::Node::EscalateError.new(
            "User #{conn.user} does not have sudo permission on #{target}",
            'SUDO_DENIED'
          )
        elsif err =~ /^Sorry, try again\./
          @logger.debug { err }
          raise Bolt::Node::EscalateError.new(
            "Sudo password for user #{conn.user} not recognized on #{target}",
            'BAD_PASSWORD'
          )
        else
          # No need to raise an error - just return the string
          err
        end
      end

      def make_wrapper_stringio(task_path, stdin, interpreter = nil)
        if interpreter
          StringIO.new(<<~SCRIPT)
            #!/bin/sh
            '#{interpreter}' '#{task_path}' <<'EOF'
            #{stdin}
            EOF
          SCRIPT
        else
          StringIO.new(<<~SCRIPT)
            #!/bin/sh
            '#{task_path}' <<'EOF'
            #{stdin}
            EOF
          SCRIPT
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

      def make_executable(path)
        result = execute(['chmod', 'u+x', path])
        if result.exit_code != 0
          message = "Could not make file '#{path}' executable: #{result.stderr.string}"
          raise Bolt::Node::FileError.new(message, 'CHMOD_ERROR')
        end
      end

      def make_tempdir
        tmpdir = @target.options.fetch('tmpdir', '/tmp')
        script_dir = @target.options.fetch('script-dir', SecureRandom.uuid)
        tmppath = File.join(tmpdir, script_dir)
        command = ['mkdir', '-m', 700, tmppath]

        result = execute(command)
        if result.exit_code != 0
          raise Bolt::Node::FileError.new("Could not make tempdir: #{result.stderr.string}", 'TEMPDIR_ERROR')
        end
        path = tmppath || result.stdout.string.chomp
        Bolt::Shell::Bash::Tmpdir.new(self, path)
      end

      def write_executable(dir, file, filename = nil)
        filename ||= File.basename(file)
        remote_path = File.join(dir.to_s, filename)
        conn.copy_file(file, remote_path)
        make_executable(remote_path)
        remote_path
      end

      # A helper to create and delete a tempdir on the remote system. Yields the
      # directory name.
      def with_tempdir
        dir = make_tempdir
        yield dir
      ensure
        if dir
          if target.options['cleanup']
            dir.delete
          else
            @logger.warn("Skipping cleanup of tmpdir #{dir}")
          end
        end
      end

      # In the case where a task is run with elevated privilege and needs stdin
      # a random string is echoed to stderr indicating that the stdin is available
      # for task input data because the sudo password has already either been
      # provided on stdin or was not needed.
      def prepend_sudo_success(sudo_id, command_str)
        command_str = "cd; #{command_str}" if conn.reset_cwd?
        "sh -c #{Shellwords.shellescape("echo #{sudo_id} 1>&2; #{command_str}")}"
      end

      def prepend_chdir(command_str)
        "sh -c #{Shellwords.shellescape("cd; #{command_str}")}"
      end

      # A helper to build up a single string that contains all of the options for
      # privilege escalation. A wrapper script is used to direct task input to stdin
      # when a tty is allocated and thus we do not need to prepend_sudo_success when
      # using the wrapper or when the task does not require stdin data.
      def build_sudoable_command_str(command_str, sudo_str, sudo_id, options)
        if options[:stdin] && !options[:wrapper]
          "#{sudo_str} #{prepend_sudo_success(sudo_id, command_str)}"
        elsif conn.reset_cwd?
          "#{sudo_str} #{prepend_chdir(command_str)}"
        else
          "#{sudo_str} #{command_str}"
        end
      end

      # Returns string with the interpreter conditionally prepended
      def inject_interpreter(interpreter, command)
        if interpreter
          if command.is_a?(Array)
            command.unshift(interpreter)
          else
            command = [interpreter, command]
          end
        end

        command.is_a?(String) ? command : Shellwords.shelljoin(command)
      end

      def execute(command, sudoable: false, **options)
        run_as = options[:run_as] || self.run_as
        escalate = sudoable && run_as && conn.user != run_as
        use_sudo = escalate && @target.options['run-as-command'].nil?

        command_str = inject_interpreter(options[:interpreter], command)

        if options[:environment]
          env_decls = options[:environment].map do |env, val|
            "#{env}=#{Shellwords.shellescape(val)}"
          end
          command_str = "#{env_decls.join(' ')} #{command_str}"
        end

        if escalate
          if use_sudo
            sudo_exec = target.options['sudo-executable'] || "sudo"
            sudo_flags = [sudo_exec, "-S", "-H", "-u", run_as, "-p", sudo_prompt]
            sudo_flags += ["-E"] if options[:environment]
            sudo_str = Shellwords.shelljoin(sudo_flags)
          else
            sudo_str = Shellwords.shelljoin(@target.options['run-as-command'] + [run_as])
          end
          command_str = build_sudoable_command_str(command_str, sudo_str, @sudo_id, options)
        end

        @logger.debug { "Executing: #{command_str}" }

        in_buffer = if !use_sudo && options[:stdin]
                      String.new(options[:stdin], encoding: 'binary')
                    else
                      String.new(encoding: 'binary')
                    end
        # Chunks of this size will be read in one iteration
        index = 0
        timeout = 0.1

        inp, out, err, t = conn.execute(command_str)
        result_output = Bolt::Node::Output.new
        read_streams = { out => String.new,
                         err => String.new }
        write_stream = in_buffer.empty? ? [] : [inp]

        # See if there's a sudo prompt
        if use_sudo
          ready_read = select([err], nil, nil, timeout * 5)
          read_streams[err] << check_sudo(err, inp, options[:stdin]) if ready_read
        end

        # True while the process is running or waiting for IO input
        while t.alive?
          # See if we can read from out or err, or write to in
          ready_read, ready_write, = select(read_streams.keys, write_stream, nil, timeout)

          # Read from out and err
          ready_read&.each do |stream|
            # Check for sudo prompt
            read_streams[stream] << if use_sudo
                                      check_sudo(stream, inp, options[:stdin])
                                    else
                                      stream.readpartial(CHUNK_SIZE)
                                    end
          rescue EOFError
          end

          # select will either return an empty array if there are no
          # writable streams or nil if no IO object is available before the
          # timeout is reached.
          writable = if ready_write.respond_to?(:empty?)
                       !ready_write.empty?
                     else
                       !ready_write.nil?
                     end

          begin
            if writable && index < in_buffer.length
              to_print = in_buffer[index..-1]
              # On Windows, select marks the input stream as writable even if
              # it's full. We need to check whether we received wait_writable
              # and treat that as not having written anything.
              written = inp.write_nonblock(to_print, exception: false)
              index += written unless written == :wait_writable

              if index >= in_buffer.length && !write_stream.empty?
                inp.close
                write_stream = []
              end
            end
          # If a task has stdin as an input_method but doesn't actually
          # read from stdin, the task may return and close the input stream
          rescue Errno::EPIPE
            write_stream = []
          end
        end
        # Read any remaining data in the pipe. Do not wait for
        # EOF in case the pipe is inherited by a child process.
        read_streams.each do |stream, _|
          loop { read_streams[stream] << stream.read_nonblock(CHUNK_SIZE) }
        rescue Errno::EAGAIN, EOFError
        end
        result_output.stdout << read_streams[out]
        result_output.stderr << read_streams[err]
        result_output.exit_code = t.value.respond_to?(:exitstatus) ? t.value.exitstatus : t.value

        if result_output.exit_code == 0
          @logger.debug { "Command returned successfully" }
        else
          @logger.info { "Command failed with exit code #{result_output.exit_code}" }
        end
        result_output
      rescue StandardError
        # Ensure we close stdin and kill the child process
        inp&.close
        t&.terminate if t&.alive?
        @logger.debug { "Command aborted" }
        raise
      end

      def sudo_prompt
        '[sudo] Bolt needs to run as another user, password: '
      end
    end
  end
end
