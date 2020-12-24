# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class LXD < Base
      class ExecConnection
        attr_reader :target

        def initialize(target)
          @target = target
          puts "target: #{@target.config}"
          # TODO: if remote unset in config, default to globally-set remote
          #  might need to shell out for this info
          @lxd_remote = default_remote
          #@lxd_remote = @target.config["lxd"]["remote"] || default_remote
          @logger = Bolt::Logger.logger(target.safe_name)
          @logger.trace("")
        end

        def connect
        # TODO: check container is running

        # TODO: get info about container, store on self
        # @container_info = get_info
          true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{@target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def download_file(source, destination)
          container = @target.name
          remote = @lxd_remote
          puts "DOWNLOAD #{remote}:#{container}#{source}"
          out, err, status = Open3.capture3('lxc', 'file', 'pull',
            "#{remote}:#{container}#{source}", destination)
          [out, err, status]
        end

        def execute(*command, _options)
          container = @target.name
          remote = @lxd_remote
          capture_options = { binmode: true }
          out, err, status = Open3.capture3('lxc', 'exec', "#{remote}:#{container}",
                                            '--', *command, capture_options)
          [out, err, status]
        end

        def write_remote_directory(source, destination)
          container = @target.name
          remote = @lxd_remote
          # TODO: check dest is absolute path
          capture_options = { binmode: true }
          out, err, status = Open3.capture3('lxc', 'file', 'push', source,
                                            "#{remote}:#{container}#{destination}",
                                            "--recursive", capture_options)
        end

        def write_remote_file(source, destination)
          container = @target.name
          remote = @lxd_remote
          # TODO: check dest is absolute path
          capture_options = { binmode: true }
          Open3.capture3('lxc', 'file', 'push', source,
                         "#{remote}:#{container}#{destination}", capture_options)
        end

        def container_tmpdir
          '/tmp'
        end

        def default_remote
          capture_options = { binmode: true }
          out, _, _ = Open3.capture3('lxc', 'remote', 'get-default', capture_options)
          out.strip
        end

        def with_remote_tmpdir
          # TODO
          dir = make_tmpdir
          yield dir
        ensure
          if dir
            if @target.options['cleanup']
              _, stderr, exitcode = execute('rm', '-rf', dir, {})
              if exitcode != 0
                @logger.warn("Failed to clean up tmpdir '#{dir}': #{stderr}")
              end
            else
              @logger.warn("Skipping cleanup of tmpdir '#{dir}'")
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
            message = "Could not make file '#{path}' executable: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'CHMOD_ERROR')
          end
        end

        def mkdirs(dirs)
          # TODO
          _, stderr, exitcode = execute('mkdir', '-p', *dirs, {})
          if exitcode != 0
            message = "Could not create directories: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def make_tmpdir
          # TODO
          tmpdir = @target.options.fetch('tmpdir', container_tmpdir)
          tmppath = "#{tmpdir}/#{SecureRandom.uuid}"

          stdout, stderr, exitcode = execute('mkdir', '-m', '700', tmppath, {})
          if exitcode != 0
            raise Bolt::Node::FileError.new("Could not make tmpdir: #{stderr}", 'TMPDIR_ERROR')
          end
          tmppath || stdout.first
        end
      end
    end
  end
end
