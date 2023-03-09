# frozen_string_literal: true

require 'logging'
require_relative '../../../bolt/node/errors'

module Bolt
  module Transport
    class Jail < Simple
      class Connection
        attr_reader :user, :target

        def initialize(target)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host
          @target = target
          @user = @target.user || ENV['USER'] || Etc.getlogin
          @logger = Bolt::Logger.logger(target.safe_name)
          @jail_info = {}
          @logger.trace("Initializing jail connection to #{target.safe_name}")
        end

        def shell
          @shell ||= Bolt::Shell::Bash.new(target, self)
        end

        def reset_cwd?
          true
        end

        def jail_id
          @jail_info['jid'].to_s
        end

        def jail_path
          @jail_info['path']
        end

        def connect
          output = JSON.parse(`jls --libxo=json`)
          @jail_info = output['jail-information']['jail'].select { |jail| jail['hostname'] == target.host }.first
          raise "Could not find a jail with name matching #{target.host}" if @jail_info.nil?
          @logger.trace { "Opened session" }
          true
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{target.safe_name}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        def execute(command)
          args = ['-lU', @user]

          jail_command = %w[jexec] + args + [jail_id] + Shellwords.split(command)
          @logger.trace { "Executing #{jail_command.join(' ')}" }

          Open3.popen3({}, *jail_command)
        rescue StandardError
          @logger.trace { "Command aborted" }
          raise
        end

        def upload_file(source, destination)
          @logger.trace { "Uploading #{source} to #{destination}" }
          jail_destination = File.join(jail_path, destination)
          FileUtils.cp(source, jail_destination)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end

        def download_file(source, destination, _download)
          @logger.trace { "Downloading #{source} to #{destination}" }
          jail_source = File.join(jail_path, source)
          FileUtils.mkdir_p(destination)
          FileUtils.cp(jail_source, destination)
        rescue StandardError => e
          raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
        end
      end
    end
  end
end
