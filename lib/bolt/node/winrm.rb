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

    def execute(command)
      result_output = Bolt::ResultOutput.new # dir?
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

    def run_script(script)
      dest = ''
      dir = ''
      result = nil

      make_tempdir.then do |value|
        dir = value
        dest = "#{dir}\\#{File.basename(script, '.*')}.ps1"
        Bolt::Success.new
      end.then do
        copy(script, dest)
      end.then do
        args = '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'
        result = execute("powershell.exe #{args} -File '#{dest}'")
      end.then do
        execute(<<-EOS)
Remove-Item -Force "#{dest}"
Remove-Item -Force "#{dir}"
EOS
        result
      end
    end
  end
end
