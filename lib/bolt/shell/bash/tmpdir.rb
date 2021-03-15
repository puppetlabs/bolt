# frozen_string_literal: true

module Bolt
  class Shell
    class Bash < Shell
      class Tmpdir
        def initialize(shell, path)
          @shell = shell
          @owner = shell.conn.user
          @path = path
          @logger = shell.logger
        end

        def to_s
          @path
        end

        def mkdirs(subdirs)
          abs_subdirs = subdirs.map { |subdir| File.join(@path, subdir) }
          result = @shell.execute(['mkdir', '-p'] + abs_subdirs)
          if result.exit_code != 0
            message = "Could not create subdirectories in '#{@path}': #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def chown(owner, force: false)
          return if owner.nil? || (owner == @owner && !force)

          result = @shell.execute(['id', '-g', owner])
          if result.exit_code != 0
            message = "Could not identify group of user #{owner}: #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'ID_ERROR')
          end
          group = result.stdout.string.chomp

          # Chown can only be run by root.
          result = @shell.execute(['chown', '-R', "#{owner}:#{group}", @path], sudoable: true, run_as: 'root')
          if result.exit_code != 0
            message = "Could not change owner of '#{@path}' to #{owner}: #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'CHOWN_ERROR')
          end

          # File ownership successfully changed, record the new owner.
          @owner = owner
        end

        def delete
          result = @shell.execute(['rm', '-rf', @path], sudoable: true, run_as: @owner)
          if result.exit_code != 0
            Bolt::Logger.warn(
              "fail_cleanup",
              "Failed to clean up tmpdir '#{@path}': #{result.stderr.string}"
            )
          end
          # For testing
          result.stderr.string
        end
      end
    end
  end
end
