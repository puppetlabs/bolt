# frozen_string_literal: true

require 'bolt/transport/sudoable/tmpdir'

module Bolt
  module Transport
    class Sudoable < Base
      class Connection
        attr_accessor :target
        def initialize(target)
          @target = target
          @run_as = nil
          @logger = Logging.logger[@target.host]
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
          tmppath = "#{tmpdir}/#{SecureRandom.uuid}"
          command = ['mkdir', '-m', 700, tmppath]

          result = execute(command)
          if result.exit_code != 0
            raise Bolt::Node::FileError.new("Could not make tempdir: #{result.stderr.string}", 'TEMPDIR_ERROR')
          end
          path = tmppath || result.stdout.string.chomp
          Sudoable::Tmpdir.new(self, path)
        end

        def write_executable(dir, file, filename = nil)
          filename ||= File.basename(file)
          remote_path = File.join(dir.to_s, filename)
          copy_file(file, remote_path)
          make_executable(remote_path)
          remote_path
        end

        # A helper to create and delete a tempdir on the remote system. Yields the
        # directory name.
        def with_tempdir
          dir = make_tempdir
          yield dir
        ensure
          dir&.delete
        end

        def execute(*_args)
          message = "#{self.class.name} must implement #{method} to execute commands"
          raise NotImplementedError, message
        end

        # In the case where a task is run with elevated privilege and needs stdin
        # a random string is echoed to stderr indicating that the stdin is available
        # for task input data because the sudo password has already either been
        # provided on stdin or was not needed.
        def prepend_sudo_success(sudo_id, command_str)
          "sh -c 'echo #{sudo_id} 1>&2; #{command_str}'"
        end

        # A helper to build up a single string that contains all of the options for
        # privilege escalation. A wrapper script is used to direct task input to stdin
        # when a tty is allocated and thus we do not need to prepend_sudo_success when
        # using the wrapper or when the task does not require stdin data.
        def build_sudoable_command_str(command_str, sudo_str, sudo_id, options)
          if options[:stdin] && !options[:wrapper]
            "#{sudo_str} #{prepend_sudo_success(sudo_id, command_str)}"
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
      end
    end
  end
end
