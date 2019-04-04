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
      end
    end
  end
end
