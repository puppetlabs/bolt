# frozen_string_literal: true

require 'docker'
require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class Docker < Base
      class Connection
        def initialize(target)
          @target = target
          @logger = Logging.logger[target.host]
        end

        def connect
          # Explicitly create the new Connection to avoid relying on global state in the Docker module.
          url = @target.options['service-url'] || ::Docker.url
          options = ::Docker.options.merge(@target.options['service-options'] || {})
          @container = ::Docker::Container.get(@target.host, {}, ::Docker::Connection.new(url, options))
          @logger.debug { "Opened session" }
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{@target.uri}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def execute(*command, options)
          command.unshift(options[:interpreter]) if options[:interpreter]
          if options[:environment]
            envs = options[:environment].map { |env, val| "#{env}=#{val}" }
            command = ['env'] + envs + command
          end

          @logger.debug { "Executing: #{command}" }
          result = @container.exec(command, options) { |stream, chunk| @logger.debug("#{stream}: #{chunk}") }
          if result[2] == 0
            @logger.debug { "Command returned successfully" }
          else
            @logger.info { "Command failed with exit code #{result[2]}" }
          end
          result
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def write_remote_file(source, destination)
          @container.store_file(destination, File.binread(source))
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def write_remote_directory(source, destination)
          tar = ::Docker::Util.create_dir_tar(source)
          mkdirs([destination])
          @container.archive_in_stream(destination) { tar.read(Excon.defaults[:chunk_size]).to_s }
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def mkdirs(dirs)
          _, stderr, exitcode = execute('mkdir', '-p', *dirs, {})
          if exitcode != 0
            message = "Could not create directories: #{stderr.join}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def make_tempdir
          tmpdir = @target.options.fetch('tmpdir', '/tmp')
          tmppath = "#{tmpdir}/#{SecureRandom.uuid}"

          stdout, stderr, exitcode = execute('mkdir', '-m', '700', tmppath, {})
          if exitcode != 0
            raise Bolt::Node::FileError.new("Could not make tempdir: #{stderr.join}", 'TEMPDIR_ERROR')
          end
          tmppath || stdout.first
        end

        def with_remote_tempdir
          dir = make_tempdir
          yield dir
        ensure
          if dir
            _, stderr, exitcode = execute('rm', '-rf', dir, {})
            if exitcode != 0
              @logger.warn("Failed to clean up tempdir '#{dir}': #{stderr.join}")
            end
          end
        end

        def write_remote_executable(dir, file, filename = nil)
          filename ||= File.basename(file)
          remote_path = File.join(dir.to_s, filename)
          write_remote_file(file, remote_path)
          make_executable(remote_path)
          remote_path
        end

        def make_executable(path)
          _, stderr, exitcode = execute('chmod', 'u+x', path, {})
          if exitcode != 0
            message = "Could not make file '#{path}' executable: #{stderr.join}"
            raise Bolt::Node::FileError.new(message, 'CHMOD_ERROR')
          end
        end
      end
    end
  end
end
