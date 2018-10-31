# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/base'

module Bolt
  module Transport
    class WinRM < Base
      PS_ARGS = %w[
        -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass
      ].freeze

      def self.options
        %w[port user password connect-timeout ssl ssl-verify tmpdir cacert extensions]
      end

      PROVIDED_FEATURES = ['powershell'].freeze

      def self.validate(options)
        ssl_flag = options['ssl']
        unless !!ssl_flag == ssl_flag
          raise Bolt::ValidationError, 'ssl option must be a Boolean true or false'
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
            if powershell_file?(remote_path)
              mapped_args = arguments.map do |a|
                "$invokeArgs.ArgumentList += @'\n#{a}\n'@"
              end.join("\n")
              output = conn.execute(<<-PS)
$invokeArgs = @{
  ScriptBlock = (Get-Command "#{remote_path}").ScriptBlock
  ArgumentList = @()
}
#{mapped_args}

try
{
  Invoke-Command @invokeArgs
}
catch
{
  Write-Error $_.Exception
  exit 1
}
          PS
            else
              path, args = *process_from_extension(remote_path)
              args += escape_arguments(arguments)
              output = conn.execute_process(path, args)
            end
            Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end
      end

      def run_task(target, task, arguments, _options = {})
        implementation = task.select_implementation(target, PROVIDED_FEATURES)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']
        input_method ||= powershell_file?(executable) ? 'powershell' : 'both'

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
                cmd = "[Environment]::SetEnvironmentVariable('#{arg}', @'\n#{val}\n'@)"
                result = conn.execute(cmd)
                if result.exit_code != 0
                  raise Bolt::Node::EnvironmentVarError.new(arg, val)
                end
              end
            end

            conn.shell_init
            output =
              if powershell_file?(remote_task_path) && stdin.nil?
                # NOTE: cannot redirect STDIN to a .ps1 script inside of PowerShell
                # must create new powershell.exe process like other interpreters
                # fortunately, using PS with stdin input_method should never happen
                if input_method == 'powershell'
                  conn.execute(<<-PS)
$private:tempArgs = Get-ContentAsJson (
  $utf8.GetString([System.Convert]::FromBase64String('#{Base64.encode64(JSON.dump(arguments))}'))
)
$allowedArgs = (Get-Command "#{remote_task_path}").Parameters.Keys
$private:taskArgs = @{}
$private:tempArgs.Keys | ? { $allowedArgs -contains $_ } | % { $private:taskArgs[$_] = $private:tempArgs[$_] }
try { & "#{remote_task_path}" @taskArgs } catch { Write-Error $_.Exception; exit 1 }
              PS
                else
                  conn.execute(%(try { & "#{remote_task_path}" } catch { Write-Error $_.Exception; exit 1 }))
                end
              else
                path, args = *process_from_extension(remote_task_path)
                conn.execute_process(path, args, stdin)
              end

            Bolt::Result.for_task(target, output.stdout.string,
                                  output.stderr.string,
                                  output.exit_code)
          end
        end
      end

      def powershell_file?(path)
        Pathname(path).extname.casecmp('.ps1').zero?
      end

      def process_from_extension(path)
        case Pathname(path).extname.downcase
        when '.rb'
          [
            'ruby.exe',
            ['-S', "\"#{path}\""]
          ]
        when '.ps1'
          [
            'powershell.exe',
            [*PS_ARGS, '-File', "\"#{path}\""]
          ]
        when '.pp'
          [
            'puppet.bat',
            ['apply', "\"#{path}\""]
          ]
        else
          # Run the script via cmd, letting Windows extension handling determine how
          [
            'cmd.exe',
            ['/c', "\"#{path}\""]
          ]
        end
      end

      def escape_arguments(arguments)
        arguments.map do |arg|
          if arg =~ / /
            "\"#{arg}\""
          else
            arg
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
