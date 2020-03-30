# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'bolt/node/output'
require 'bolt/util'

module Bolt
  module Transport
    class Local < Simple
      class Connection
        attr_accessor :user, :logger, :target

        CHUNK_SIZE = 4096
        PS_ARGS = %w[-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass].freeze

        def initialize(target)
          @target = target
          # The familiar problem: Etc.getlogin is broken on osx
          @user = ENV['USER'] || Etc.getlogin
          @logger = Logging.logger[self]
        end

        def shell
          @shell ||= if Bolt::Util.windows?
                       Bolt::Shell::Powershell.new(target, self)
                     else
                       Bolt::Shell::Bash.new(target, self)
                     end
        end

        def copy_file(source, dest)
          @logger.debug { "Uploading #{source}, to #{dest}" }
          if source.is_a?(StringIO)
            Tempfile.create(File.basename(dest)) do |f|
              f.write(source.read)
              FileUtils.mv(t, dest)
            end
          else
            # Mimic the behavior of `cp --remove-destination`
            # since the flag isn't supported on MacOS
            FileUtils.cp_r(source, dest, remove_destination: true)
          end
        rescue StandardError => e
          message = "Could not copy file to #{dest}: #{e}"
          raise Bolt::Node::FileError.new(message, 'COPY_ERROR')
        end

        def execute(command, **options, &blk)
          command_arr = options[:environment].nil? ? Array(command) : [options[:environment], *command]

          # All commands are executed via powershell for now
          if Bolt::Util.windows?
            command_arr = ['powershell.exe', *PS_ARGS, *command_arr]
          end

          inp, out, err, t = Open3.popen3(*command_arr)
        end
      end
    end
  end
end
