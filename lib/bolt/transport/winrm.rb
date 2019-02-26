# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/base'
require 'bolt/transport/powershell'

module Bolt
  module Transport
    class WinRM < Base
      def self.options
        %w[
          port user password connect-timeout ssl ssl-verify tmpdir cacert
          extensions interpreters file-protocol smb-port
        ]
      end

      def self.default_options
        {
          'connect-timeout' => 10,
          'ssl' => true,
          'ssl-verify' => true,
          'file-protocol' => 'winrm'
        }
      end

      def provided_features
        ['powershell']
      end

      def default_input_method(executable)
        input_method ||= Powershell.powershell_file?(executable) ? 'powershell' : 'both'
        input_method
      end

      def self.validate(options)
        ssl_flag = options['ssl']
        unless !!ssl_flag == ssl_flag
          raise Bolt::ValidationError, 'ssl option must be a Boolean true or false'
        end

        if ssl_flag && (options['file-protocol'] == 'smb')
          raise Bolt::ValidationError, 'SMB file transfers are not allowed with SSL enabled'
        end

        ssl_verify_flag = options['ssl-verify']
        unless !!ssl_verify_flag == ssl_verify_flag
          raise Bolt::ValidationError, 'ssl-verify option must be a Boolean true or false'
        end

        timeout_value = options['connect-timeout']
        unless timeout_value.is_a?(Integer) || timeout_value.nil?
          error_msg = "connect-timeout value must be an Integer, received #{timeout_value}:#{timeout_value.class}"
          raise Bolt::ValidationError, error_msg
        end
      end

      def initialize
        super
        require 'winrm'
        require 'winrm-fs'

        @transport_logger = Logging.logger[::WinRM]
        @transport_logger.level = :warn
      end

      def with_connection(target)
        conn = Connection.new(target, @transport_logger)
        conn.connect
        yield conn
      ensure
        begin
          conn&.disconnect
        rescue StandardError => ex
          logger.info("Failed to close connection to #{target.uri} : #{ex.message}")
        end
      end

      def upload(target, source, destination, _options = {})
        with_connection(target) do |conn|
          conn.write_remote_file(source, destination)
          Bolt::Result.for_upload(target, source, destination)
        end
      end

      def run_command(target, command, _options = {})
        with_connection(target) do |conn|
          output = conn.execute(command)
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_script(target, script, arguments, _options = {})
        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_connection(target) do |conn|
          conn.with_remote_tempdir do |dir|
            remote_path = conn.write_remote_executable(dir, script)
            if Powershell.powershell_file?(remote_path)
              output = conn.execute(Powershell.run_script(arguments, remote_path))
            else
              path, args = *Powershell.process_from_extension(remote_path)
              args += Powershell.escape_arguments(arguments)
              output = conn.execute_process(path, args)
            end
            Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end
      end

      def run_task(target, task, arguments, _options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']
        input_method ||= Powershell.powershell_file?(executable) ? 'powershell' : 'both'

        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_connection(target) do |conn|
          conn.with_remote_tempdir do |dir|
            if extra_files.empty?
              task_dir = dir
            else
              # TODO: optimize upload of directories
              arguments['_installdir'] = dir
              task_dir = File.join(dir, task.tasks_dir)
              conn.mkdirs([task_dir] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })
              extra_files.each do |file|
                conn.write_remote_file(file['path'], File.join(dir, file['name']))
              end
            end

            remote_task_path = conn.write_remote_executable(task_dir, executable)

            if STDIN_METHODS.include?(input_method)
              stdin = JSON.dump(arguments)
            end

            if ENVIRONMENT_METHODS.include?(input_method)
              envify_params(arguments).each do |(arg, val)|
                cmd = Powershell.set_env(arg, val)
                result = conn.execute(cmd)
                if result.exit_code != 0
                  raise Bolt::Node::EnvironmentVarError.new(arg, val)
                end
              end
            end

            conn.shell_init
            output =
              if Powershell.powershell_file?(remote_task_path) && stdin.nil?
                conn.execute(Powershell.run_ps_task(arguments, remote_task_path, input_method))
              else
                interpreter = select_interpreter(remote_task_path, target.options['interpreters'])
                if interpreter
                  path = interpreter
                  args = [remote_task_path]
                else
                  path, args = *Powershell.process_from_extension(remote_task_path)
                end
                conn.execute_process(path, args, stdin)
              end

            Bolt::Result.for_task(target, output.stdout.string,
                                  output.stderr.string,
                                  output.exit_code)
          end
        end
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end
    end
  end
end

require 'bolt/transport/winrm/connection'
