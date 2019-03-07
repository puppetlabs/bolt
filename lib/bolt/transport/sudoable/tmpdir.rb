# frozen_string_literal: true

module Bolt
  module Transport
    class Sudoable < Base
      class Tmpdir
        def initialize(node, path)
          @conn = node
          @owner = node.user
          @path = path
          @logger = node.logger
        end

        def to_s
          @path
        end

        def mkdirs(subdirs)
          abs_subdirs = subdirs.map { |subdir| File.join(@path, subdir) }
          result = @conn.execute(['mkdir', '-p'] + abs_subdirs)
          if result.exit_code != 0
            message = "Could not create subdirectories in '#{@path}': #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def chown(owner)
          return if owner.nil? || owner == @owner

          result = @conn.execute(['id', '-g', owner])
          if result.exit_code != 0
            message = "Could not identify group of user #{owner}: #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'ID_ERROR')
          end
          group = result.stdout.string.chomp

          # Chown can only be run by root.
          result = @conn.execute(['chown', '-R', "#{owner}:#{group}", @path], sudoable: true, run_as: 'root')
          if result.exit_code != 0
            message = "Could not change owner of '#{@path}' to #{owner}: #{result.stderr.string}"
            raise Bolt::Node::FileError.new(message, 'CHOWN_ERROR')
          end

          # File ownership successfully changed, record the new owner.
          @owner = owner
        end

        def delete
          result = @conn.execute(['rm', '-rf', @path], sudoable: true, run_as: @owner)
          if result.exit_code != 0
            @logger.warn("Failed to clean up tempdir '#{@path}': #{result.stderr.string}")
          end
          # For testing
          result.stderr.string
        end
      end
    end
  end
end
