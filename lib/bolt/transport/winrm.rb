require 'bolt/transport/base'

module Bolt
  module Transport
    class WinRM < Base
      STDIN_METHODS       = %w[both stdin].freeze
      ENVIRONMENT_METHODS = %w[both environment].freeze

      PS_ARGS = %w[
        -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass
      ].freeze

      def initialize(_config, _executor = Concurrent.global_immediate_executor)
        super
        require 'winrm'
        require 'winrm-fs'
      end

      def with_connection(target)
        conn = Connection.new(target)
        conn.connect
        yield conn
      ensure
        begin
          conn.disconnect if conn
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
        with_connection(target) do |conn|
          conn.with_remote_file(script) do |remote_path|
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

      def run_task(target, task, input_method, arguments, _options = {})
        with_connection(target) do |conn|
          if STDIN_METHODS.include?(input_method)
            stdin = JSON.dump(arguments)
          end

          if ENVIRONMENT_METHODS.include?(input_method)
            arguments.each do |(arg, val)|
              cmd = "[Environment]::SetEnvironmentVariable('PT_#{arg}', '#{val}')"
              result = conn.execute(cmd)
              if result.exit_code != 0
                raise EnvironmentVarError(var, value)
              end
            end
          end

          conn.with_remote_file(task) do |remote_path|
            output =
              if powershell_file?(remote_path) && stdin.nil?
                # NOTE: cannot redirect STDIN to a .ps1 script inside of PowerShell
                # must create new powershell.exe process like other interpreters
                # fortunately, using PS with stdin input_method should never happen
                if input_method == 'powershell'
                  conn.execute(<<-PS)
$private:taskArgs = Get-ContentAsJson (
  $utf8.GetString([System.Convert]::FromBase64String('#{Base64.encode64(JSON.dump(arguments))}'))
)
try { & "#{remote_path}" @taskArgs } catch { exit 1 }
              PS
                else
                  conn.execute(%(try { & "#{remote_path}" } catch { exit 1 }))
                end
              else
                path, args = *process_from_extension(remote_path)
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
    end
  end
end

require 'bolt/transport/winrm/connection'
