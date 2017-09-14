require 'winrm'
require 'winrm-fs'
require 'bolt/result'

module Bolt
  class WinRM < Node
    def initialize(host, port, user, password, tty, shell = :powershell)
      super(host, port, user, password, tty)

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

    def execute(command, _ = {})
      result_output = Bolt::ResultOutput.new

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

    def upload(source, destination)
      fs = ::WinRM::FS::FileManager.new(@connection)
      fs.upload(source, destination)
      Bolt::Success.new
    rescue StandardError => ex
      Bolt::ExceptionFailure.new(ex)
    end

    def make_tempdir
      result = execute(<<-PS)
$parent = [System.IO.Path]::GetTempPath()
$name = [System.IO.Path]::GetRandomFileName()
$path = Join-Path $parent $name
New-Item -ItemType Directory -Path $path | Out-Null
$path
PS
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
        upload(file, dest)
      end.then do
        result = yield dest
      end.then do
        execute(<<-PS)
Remove-Item -Force "#{dest}"
Remove-Item -Force "#{dir}"
PS
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
      if input_method == 'stdin'
        raise NotImplementedError,
              "Sending task arguments via stdin to PowerShell is not supported"
      end

      arguments.reduce(Bolt::Success.new) do |result, (arg, val)|
        result.then do
          cmd = "[Environment]::SetEnvironmentVariable('PT_#{arg}', '#{val}')"
          execute(cmd)
        end
      end.then do
        with_remote_file(task) do |remote_path|
          args = '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'
          execute("powershell.exe #{args} -File '#{remote_path}'")
        end
      end
    end
  end
end
