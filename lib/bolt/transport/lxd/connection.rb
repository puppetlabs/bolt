# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class LXD < Simple
      class Connection
        attr_reader :user, :target

        def initialize(target, options)
          @target = target
          @user = ENV['USER'] || Etc.getlogin
          @options = options
          @lxd_remote = @target.config.dig('lxd', 'remote') || default_remote
          @logger = Bolt::Logger.logger(target.safe_name)
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
          container = @target.uri
          remote = @lxd_remote
          puts "DOWNLOAD #{remote}:#{container}#{source}"
          out, err, status = Open3.capture3('lxc', 'file', 'pull',
                                            "#{remote}:#{container}#{source}", destination)
          [out, err, status]
        end

        def shell
          Bolt::Shell::Bash.new(target, self)
        end

        def execute(command)
          container = @target.uri
          remote = @lxd_remote
          env_vars = []
          if command.start_with?("PT_")
            parts = Shellwords.split(command)
            env_vars, command = parts.partition { |p| p.start_with?("PT_") }
            command = Shellwords.shelljoin(command)
          end

          command_options = []
          # See `lxc exec --help` for information on flags`
          env_vars.each do |env_var|
            command_options += %W[--env #{env_var}]
          end

          lxc_command = Shellwords.split(command)

          @logger.info { "Executing: exec #{command_options}" }
          capture_options = { binmode: true }
          # capture_options[:stdin_data] = options[:stdin] unless options[:stdin].nil?
          out, err, status = Open3.capture3('lxc', 'exec', *command_options, "#{remote}:#{container}",
                                            '--', *lxc_command, capture_options)
          [out, err, status]
        end

        def upload(source, destination)
          if File.directory?(source)
            write_remote_directory(source, destination)
          else
            write_remote_file(source, destination)
          end
          Bolt::Result.for_upload(@target, source, destination)
        end

        def download(source, destination, _download)
          download = File.join(destination, Bolt::Util.unix_basename(source))
          _stdout_str, stderr_str, status = download_file(source, destination)
          unless status.exitstatus.zero?
            raise "Error downloading content from container #{@target}: #{stderr_str}"
          end
          Bolt::Result.for_download(target, source, destination, download)
        end

        def write_remote_directory(source, destination)
          container = @target.uri
          remote = @lxd_remote
          # TODO: check dest is absolute path
          capture_options = { binmode: true }
          _out, _err, _status = Open3.capture3('lxc', 'file', 'push', source,
                                               "#{remote}:#{container}#{destination}",
                                               "--recursive", capture_options)
        end

        def write_remote_file(source, destination)
          container = @target.uri
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
          out, _err, _status = Open3.capture3('lxc', 'remote', 'get-default', capture_options)
          out.strip
        end

        def with_remote_tmpdir
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
          _, stderr, exitcode = execute('mkdir', '-p', *dirs, {})
          if exitcode != 0
            message = "Could not create directories: #{stderr}"
            raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
          end
        end

        def make_tmpdir
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
