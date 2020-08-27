# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tempfile'
require 'bolt/node/output'
require 'bolt/util'

module Bolt
  module Transport
    class Local < Simple
      class Connection
        attr_accessor :user, :logger, :target

        def initialize(target)
          @target = target
          # The familiar problem: Etc.getlogin is broken on osx
          @user = ENV['USER'] || Etc.getlogin
          @logger = Bolt::Logger.logger(self)
        end

        def shell
          @shell ||= if Bolt::Util.windows?
                       Bolt::Shell::Powershell.new(target, self)
                     else
                       Bolt::Shell::Bash.new(target, self)
                     end
        end

        def upload_file(source, dest)
          @logger.trace { "Uploading #{source} to #{dest}" }
          if source.is_a?(StringIO)
            Tempfile.create(File.basename(dest)) do |f|
              f.write(source.read)
              f.close
              FileUtils.mv(f, dest)
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

        def download_file(source, dest, _download)
          @logger.trace { "Downloading #{source} to #{dest}" }
          # Create the destination directory for the target, or the
          # copied file will have the target's name
          FileUtils.mkdir_p(dest)
          # Mimic the behavior of `cp --remove-destination`
          # since the flag isn't supported on MacOS
          FileUtils.cp_r(source, dest, remove_destination: true)
        rescue StandardError => e
          message = "Could not download file to #{dest}: #{e}"
          raise Bolt::Node::FileError.new(message, 'DOWNLOAD_ERROR')
        end

        def execute(command)
          if Bolt::Util.windows?
            # If it's already a powershell command then invoke it normally.
            # Otherwise, wrap it in powershell.exe.
            unless command.start_with?('powershell.exe')
              cmd = Bolt::Shell::Powershell::Snippets.exit_with_code(command)
              command = ['powershell.exe', *Bolt::Shell::Powershell::PS_ARGS, '-Command', cmd]
            end
          end

          Open3.popen3(*command)
        end

        # This is used by the Bash shell to decide whether to `cd` before
        # executing commands as a run-as user
        def reset_cwd?
          false
        end

        def max_command_length
          if Bolt::Util.windows?
            32000
          end
        end
      end
    end
  end
end
