# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/base'
require 'bolt/transport/powershell'

module Bolt
  module Transport
    class WinRM < Base
      OPTIONS = {
        "cacert"          => "The path to the CA certificate.",
        "connect-timeout" => "How long Bolt should wait when establishing connections.",
        "extensions"      => "List of file extensions that are accepted for scripts or tasks. "\
                              "Scripts with these file extensions rely on the target's file type "\
                              "association to run. For example, if Python is installed on the system, "\
                              "a `.py` script runs with `python.exe`. The extensions `.ps1`, `.rb`, and "\
                              "`.pp` are always allowed and run via hard-coded executables.",
        "file-protocol"   => "Which file transfer protocol to use. Either `winrm` or `smb`. Using `smb` is "\
                              "recommended for large file transfers.",
        "host"            => "Host name.",
        "interpreters"    => "A map of an extension name to the absolute path of an executable, "\
                              "enabling you to override the shebang defined in a task executable. The "\
                              "extension can optionally be specified with the `.` character (`.py` and "\
                              "`py` both map to a task executable `task.py`) and the extension is case "\
                              "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                              "Bolt Ruby interpreter by default.",
        "password"        => "Login password. **Required unless using Kerberos.**",
        "port"            => "Connection port.",
        "realm"           => "Kerberos realm (Active Directory domain) to authenticate against.",
        "smb-port"        => "With file-protocol set to smb, this is the port to establish a connection on.",
        "ssl"             => "When true, Bolt uses secure https connections for WinRM.",
        "ssl-verify"      => "When true, verifies the targets certificate matches the cacert.",
        "tmpdir"          => "The directory to upload and execute temporary files on the target.",
        "user"            => "Login user. **Required unless using Kerberos.**",
        "basic-auth-only" => "Force basic authentication."
      }.freeze

      def self.options
        OPTIONS.keys
      end

      def self.default_options
        {
          'connect-timeout' => 10,
          'ssl' => true,
          'ssl-verify' => true,
          'file-protocol' => 'winrm',
          'basic-auth-only' => false
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
        
        basic_auth_only_flag = options['basic-auth-only']
        unless !!basic_auth_only_flag == basic_auth_only_flag
          raise Bolt::ValidationError, 'basic-auth-only option must be a Boolean true or false'
        end

        if ssl_flag && (options['file-protocol'] == 'smb')
          raise Bolt::ValidationError, 'SMB file transfers are not allowed with SSL enabled'
        end

        if ssl_flag && (ca_path = options['cacert'])
          Bolt::Util.validate_file('cacert', ca_path)
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
        rescue StandardError => e
          logger.info("Failed to close connection to #{target.safe_name} : #{e.message}")
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
          Bolt::Result.for_command(target,
                                   output.stdout.string,
                                   output.stderr.string,
                                   output.exit_code,
                                   'command', command)
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
            Bolt::Result.for_command(target,
                                     output.stdout.string,
                                     output.stderr.string,
                                     output.exit_code,
                                     'script', script)
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
                if (interpreter = select_interpreter(remote_task_path, target.options['interpreters']))
                  path = interpreter
                  args = [remote_task_path]
                else
                  path, args = *Powershell.process_from_extension(remote_task_path)
                end
                conn.execute_process(path, args, stdin)
              end

            Bolt::Result.for_task(target, output.stdout.string,
                                  output.stderr.string,
                                  output.exit_code,
                                  task.name)
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
