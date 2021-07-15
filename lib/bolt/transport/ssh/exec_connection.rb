# frozen_string_literal: true

require 'open3'

module Bolt
  module Transport
    class SSH < Simple
      class ExecConnection
        attr_reader :user, :target

        def initialize(target)
          raise Bolt::ValidationError, "Target #{target.safe_name} does not have a host" unless target.host

          @target = target
          begin
            ssh_config = Net::SSH::Config.for(target.host)
            @user = @target.user || ssh_config[:user] || Etc.getlogin
          rescue StandardError
            @user = @target.user || Etc.getlogin
          end
          @logger = Bolt::Logger.logger(self)
        end

        # This is used to verify we can connect to targets with `connected?`
        def connect
          cmd = build_ssh_command('exit')
          _, err, stat = Open3.capture3(*cmd)
          unless stat.success?
            raise Bolt::Node::ConnectError.new(
              "Failed to connect to #{@target.safe_name}: #{err}",
              'CONNECT_ERROR'
            )
          end
        end

        def disconnect; end

        def shell
          Bolt::Shell::Bash.new(@target, self)
        end

        def userhost
          "#{@user}@#{@target.host}"
        end

        def ssh_opts
          cmd = []
          # BatchMode is SSH's noninteractive option: if key authentication
          # fails it will error out instead of falling back to password prompt
          batch_mode = @target.transport_config['batch-mode'] ? 'yes' : 'no'
          cmd += %W[-o BatchMode=#{batch_mode}]

          cmd += %W[-o Port=#{@target.port}] if @target.port

          if @target.transport_config.key?('host-key-check')
            hkc = @target.transport_config['host-key-check'] ? 'yes' : 'no'
            cmd += %W[-o StrictHostKeyChecking=#{hkc}]
          end

          if (key = target.transport_config['private-key'])
            cmd += ['-i', key]
          end
          cmd
        end

        def build_ssh_command(command)
          ssh_conf = @target.transport_config['ssh-command'] || 'ssh'
          ssh_cmd = Array(ssh_conf)
          ssh_cmd += ssh_opts
          ssh_cmd << userhost
          ssh_cmd << command
        end

        def upload_file(source, dest)
          @logger.trace { "Uploading #{source} to #{dest}" } unless source.is_a?(StringIO)

          cp_conf = @target.transport_config['copy-command'] || ["scp", "-r"]
          cp_cmd = Array(cp_conf)
          cp_cmd += ssh_opts

          _, err, stat = if source.is_a?(StringIO)
                           Tempfile.create(File.basename(dest)) do |f|
                             f.write(source.read)
                             f.close
                             cp_cmd << f.path
                             cp_cmd << "#{userhost}:#{Shellwords.escape(dest)}"
                             Open3.capture3(*cp_cmd)
                           end
                         else
                           cp_cmd << source
                           cp_cmd << "#{userhost}:#{Shellwords.escape(dest)}"
                           Open3.capture3(*cp_cmd)
                         end

          if stat.success?
            @logger.trace "Successfully uploaded #{source} to #{dest}"
          else
            message = "Could not copy file to #{dest}: #{err}"
            raise Bolt::Node::FileError.new(message, 'COPY_ERROR')
          end
        end

        def download_file(source, dest, _download)
          @logger.trace { "Downloading #{userhost}:#{source} to #{dest}" }

          FileUtils.mkdir_p(dest)

          cp_conf = @target.transport_config['copy-command'] || ["scp", "-r"]
          cp_cmd = Array(cp_conf)
          cp_cmd += ssh_opts
          cp_cmd << "#{userhost}:#{Shellwords.escape(source)}"
          cp_cmd << dest

          _, err, stat = Open3.capture3(*cp_cmd)

          if stat.success?
            @logger.trace "Successfully downloaded #{userhost}:#{source} to #{dest}"
          else
            message = "Could not copy file to #{dest}: #{err}"
            raise Bolt::Node::FileError.new(message, 'COPY_ERROR')
          end
        end

        def execute(command)
          cmd_array = build_ssh_command(command)
          Open3.popen3(*cmd_array)
        end

        # This is used by the Bash shell to decide whether to `cd` before
        # executing commands as a run-as user
        def reset_cwd?
          true
        end
      end
    end
  end
end
