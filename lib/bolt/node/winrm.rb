require 'winrm'
require 'winrm-fs'

module Bolt
  class WinRM < Node
    def initialize(endpoint, user, password, shell = :powershell)
      @endpoint = endpoint
      @user = user
      @password = password
      @shell = shell
      @connection = ::WinRM::Connection.new(endpoint: @endpoint,
                                            user: @user,
                                            password: @password)
    end

    def connect
      @session = @connection.shell(@shell)
    end

    def disconnect
      @session.close if @session
    end

    def execute(command)
      @session.run(command) do |stdout, stderr|
        print stdout
        print stderr
      end
    end

    def copy(source, destination)
      fs = ::WinRM::FS::FileManager.new(@connection)
      fs.upload(source, destination)
    end

    def make_tempdir
      execute(<<-EOS).stdout.chomp
$parent = [System.IO.Path]::GetTempPath()
$name = [System.IO.Path]::GetRandomFileName()
$path = Join-Path $parent $name
New-Item -ItemType Directory -Path $path | Out-Null
$path
EOS
    end

    def run_script(script)
      dir = make_tempdir
      remote_path = "#{dir}\\#{File.basename(script, File.extname(script))}.ps1"
      copy(script, remote_path)
      args = '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'
      execute("powershell.exe #{args} -File '#{remote_path}'")
      execute(<<-EOS)
Remove-Item -Force "#{remote_path}"
Remove-Item -Force "#{dir}"
EOS
    end
  end
end
