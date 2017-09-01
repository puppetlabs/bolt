require 'winrm'
require 'winrm-fs'
require 'bolt/result'

module Bolt
  class WinRM < Node
    def initialize(host, port, user, password, shell = :powershell)
      super(host, port, user, password)

      @shell = shell
      @endpoint = "http://#{host}:#{port}/wsman"
      @connection = ::WinRM::Connection.new(endpoint: @endpoint,
                                            user: @user,
                                            password: @password)
      @connection.logger = @transport_logger
    end

    def connect
      @session = @connection.shell(@shell)
    end

    def disconnect
      @session.close if @session
    end

    def execute(command, options = {})
      result_output = Bolt::ResultOutput.new

      if options[:stdin]
        # powershell uses backtick to escape quotes
        escaped_stdin = options[:stdin].gsub(/"/, '`"')
        command = "cmd.exe /c echo \"#{escaped_stdin}\" | #{command}"
      end

      output = @session.run(command) do |stdout, stderr|
        result_output.stdout << stdout
        result_output.stderr << stderr
      end
      if output.exitcode.zero?
        Bolt::Success.new(result_output.stdout.string, result_output)
      else
        Bolt::Failure.new(output.exitcode, result_output)
      end
    end

    def copy(source, destination)
      fs = ::WinRM::FS::FileManager.new(@connection)
      fs.upload(source, destination)
      Bolt::Success.new
    rescue => ex
      Bolt::ExceptionFailure.new(ex)
    end

    def make_tempdir
      result = execute(<<-EOS)
$parent = [System.IO.Path]::GetTempPath()
$name = [System.IO.Path]::GetRandomFileName()
$path = Join-Path $parent $name
New-Item -ItemType Directory -Path $path | Out-Null
$path
EOS
      result.then { |stdout| Bolt::Success.new(stdout.chomp) }
    end

    def with_remote_file(file)
      dest = ''
      dir = ''
      result = nil

      make_tempdir.then do |value|
        dir = value
        dest = "#{dir}\\#{File.basename(file, '.*')}.ps1"
        Bolt::Success.new
      end.then do
        copy(file, dest)
      end.then do
        result = yield dest
      end.then do
        execute(<<-EOS)
Remove-Item -Force "#{dest}"
Remove-Item -Force "#{dir}"
EOS
        result
      end
    end

    def run_script(script)
      with_remote_file(script) do |remote_path|
        args = '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'
        execute("powershell.exe #{args} -File '#{remote_path}'")
      end
    end

    def run_task(task, input_method, arguments)
      stdin = STDIN_METHODS.include?(input_method) ? JSON.dump(arguments) : nil

      arguments.reduce(Bolt::Success.new) do |result, (arg, val)|
        result.then do
          if ENVIRONMENT_METHODS.include?(input_method)
            cmd = "[Environment]::SetEnvironmentVariable('PT_#{arg}', '#{val}')"
            execute(cmd)
          else
            result
          end
        end
      end.then do
        with_remote_file(task) do |remote_path|
          args = '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'
          execute("powershell.exe #{args} -File '#{remote_path}'", stdin: stdin)
        end
      end
    end
  end
end
