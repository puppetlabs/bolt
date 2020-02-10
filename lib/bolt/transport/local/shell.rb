# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'bolt/node/output'
require 'bolt/util'

module Bolt
  module Transport
    class Local < Sudoable
      class Shell < Sudoable::Connection
        attr_accessor :user, :logger, :target
        attr_writer :run_as

        CHUNK_SIZE = 4096

        def initialize(target)
          @target = target
          # The familiar problem: Etc.getlogin is broken on osx
          @user = ENV['USER'] || Etc.getlogin
          @run_as = target.options['run-as']
          @logger = Logging.logger[self]
          @sudo_id = SecureRandom.uuid
        end

        # If prompted for sudo password, send password to stdin and return an
        # empty string. Otherwise, check for sudo errors and raise Bolt error.
        # If sudo_id is detected, that means the task needs to have stdin written.
        # If error is not sudo-related, return the stderr string to be added to
        # node output
        def handle_sudo(stdin, err, pid, sudo_stdin)
          if err.include?(Sudoable.sudo_prompt)
            # A wild sudo prompt has appeared!
            if @target.options['sudo-password']
              stdin.write("#{@target.options['sudo-password']}\n")
              ''
            else
              raise Bolt::Node::EscalateError.new(
                "Sudo password for user #{@user} was not provided for localhost",
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
            handle_sudo_errors(err, pid)
          end
        end

        def handle_sudo_errors(err, pid)
          if err =~ /^#{@user} is not in the sudoers file\./
            @logger.debug { err }
            raise Bolt::Node::EscalateError.new(
              "User #{@user} does not have sudo permission on localhost",
              'SUDO_DENIED'
            )
          elsif err =~ /^Sorry, try again\./
            @logger.debug { err }
            # CODEREVIEW can we kill a sudo process without sudo password?
            Process.kill('TERM', pid)
            raise Bolt::Node::EscalateError.new(
              "Sudo password for user #{@user} not recognized on localhost",
              'BAD_PASSWORD'
            )
          else
            # No need to raise an error - just return the string
            err
          end
        end

        def copy_file(source, dest)
          @logger.debug { "Uploading #{source}, to #{dest}" }
          if source.is_a?(StringIO)
            File.open("tempfile", "w") { |f| f.write(source.read) }
            execute(['mv', 'tempfile', dest])
          else
            # Mimic the behavior of `cp --remove-destination`
            # since the flag isn't supported on MacOS
            result = execute(['rm', '-rf', dest])
            if result.exit_code != 0
              message = "Could not remove existing file #{dest}: #{result.stderr.string}"
              raise Bolt::Node::FileError.new(message, 'REMOVE_ERROR')
            end

            result = execute(['cp', '-r', source, dest])
            if result.exit_code != 0
              message = "Could not copy file to #{dest}: #{result.stderr.string}"
              raise Bolt::Node::FileError.new(message, 'COPY_ERROR')
            end
          end
        end

        def with_tmpscript(script)
          with_tempdir do |dir|
            dest = File.join(dir.to_s, File.basename(script))
            copy_file(script, dest)
            yield dest, dir
          end
        end

        # See if there's a sudo prompt in the output
        # If not, return the output
        def check_sudo(out, inp, pid, stdin)
          buffer = out.readpartial(CHUNK_SIZE)
          # Split on newlines, including the newline
          lines = buffer.split(/(?<=[\n])/)
          # handle_sudo will return the line if it is not a sudo prompt or error
          lines.map! { |line| handle_sudo(inp, line, pid, stdin) }
          lines.join("")
        # If stream has reached EOF, no password prompt is expected
        # return an empty string
        rescue EOFError
          ''
        end

        def execute(command, sudoable: true, **options)
          run_as = options[:run_as] || self.run_as
          escalate = sudoable && run_as && @user != run_as
          use_sudo = escalate && @target.options['run-as-command'].nil?

          command_str = inject_interpreter(options[:interpreter], command)

          if escalate
            if use_sudo
              sudo_exec = target.options['sudo-executable'] || "sudo"
              sudo_flags = [sudo_exec, "-k", "-S", "-u", run_as, "-p", Sudoable.sudo_prompt]
              sudo_flags += ["-E"] if options[:environment]
              sudo_str = Shellwords.shelljoin(sudo_flags)
            else
              sudo_str = Shellwords.shelljoin(@target.options['run-as-command'] + [run_as])
            end
            command_str = build_sudoable_command_str(command_str, sudo_str, @sudo_id, options)
          end

          command_arr = options[:environment].nil? ? [command_str] : [options[:environment], command_str]

          # Prepare the variables!
          result_output = Bolt::Node::Output.new
          # Sudo handler will pass stdin if needed.
          in_buffer = !use_sudo && options[:stdin] ? options[:stdin] : ''
          # Chunks of this size will be read in one iteration
          index = 0
          timeout = 0.1

          inp, out, err, t = Open3.popen3(*command_arr)
          read_streams = { out => String.new,
                           err => String.new }
          write_stream = in_buffer.empty? ? [] : [inp]

          # See if there's a sudo prompt
          if use_sudo
            ready_read = select([err], nil, nil, timeout * 5)
            read_streams[err] << check_sudo(err, inp, t.pid, options[:stdin]) if ready_read
          end

          # True while the process is running or waiting for IO input
          while t.alive?
            # See if we can read from out or err, or write to in
            ready_read, ready_write, = select(read_streams.keys, write_stream, nil, timeout)

            # Read from out and err
            ready_read&.each do |stream|
              # Check for sudo prompt
              read_streams[stream] << if use_sudo
                                        check_sudo(stream, inp, t.pid, options[:stdin])
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
                written = inp.write_nonblock to_print
                index += written

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
          result_output.exit_code = t.value.exitstatus
          result_output
        end
      end
    end
  end
end
