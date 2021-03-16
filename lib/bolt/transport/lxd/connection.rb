# frozen_string_literal: true

require 'logging'
require 'bolt/node/errors'

module Bolt
  module Transport
    class LXD < Simple
      class Connection
        attr_reader :user, :target

        def initialize(target, options)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host

          @target = target
          @user = ENV['USER'] || Etc.getlogin
          @options = options
          @logger = Bolt::Logger.logger(target.safe_name)
          @logger.trace("Initializing LXD connection to #{target.safe_name}")
        end

        def shell
          Bolt::Shell::Bash.new(target, self)
        end

        def container_id
          "#{@target.transport_config['remote']}:#{@target.host}"
        end

        def connect
          out, err, status = execute_local_command(%W[list #{container_id} --format json])
          unless status.exitstatus.zero?
            raise "Error listing available containers: #{err}"
          end
          containers = JSON.parse(out)
          if containers.empty?
            raise "Could not find a container with name or ID matching '#{container_id}'"
          end
          @logger.trace("Opened session")
          true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{container_id}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def add_env_vars(env_vars)
          @env_vars = env_vars.each_with_object([]) do |env_var, acc|
            acc << "--env"
            acc << "#{env_var[0]}=#{Shellwords.shellescape(env_var[1])}"
          end
        end

        def execute(command)
          lxc_command = %w[lxc exec]
          lxc_command += @env_vars if @env_vars
          lxc_command += %W[#{container_id} -- sh -c #{Shellwords.shellescape(command)}]

          @logger.trace { "Executing: #{lxc_command.join(' ')}" }
          Open3.popen3(lxc_command.join(' '))
        end

        private def execute_local_command(command)
          Open3.capture3('lxc', *command, { binmode: true })
        end

        def upload_file(source, destination)
          @logger.trace { "Uploading #{source} to #{destination}" }
          args = %w[--create-dirs]
          if File.directory?(source)
            args << '--recursive'
            # If we don't do this, LXD will upload to
            # /tmp/d2020-11/d2020-11/dir instead of /tmp/d2020-11/dir
            destination = Pathname.new(destination).dirname.to_s
          end
          cmd = %w[file push] + args + %W[#{source} #{container_id}#{destination}]
          _out, err, stat = execute_local_command(cmd)
          unless stat.exitstatus.zero?
            raise "Error writing to #{container_id}: #{err}"
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def download_file(source, destination, _download)
          @logger.trace { "Downloading #{source} to #{destination}" }
          FileUtils.mkdir_p(destination)
          _out, err, stat = execute_local_command(%W[file pull --recursive #{container_id}#{source} #{destination}])
          unless stat.exitstatus.zero?
            raise "Error downloading content from container #{container_id}: #{err}"
          end
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end
      end
    end
  end
end
