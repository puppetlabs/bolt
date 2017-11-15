require 'winrm'
require 'winrm-fs'
require 'bolt/result'

module Bolt
  class WinRM < Node
    def initialize(host, port, user, password, shell: :powershell, **kwargs)
      super(host, port, user, password, **kwargs)

      @shell = shell
      @endpoint = "http://#{host}:#{port}/wsman"
    end

    def connect
      @connection = ::WinRM::Connection.new(endpoint: @endpoint,
                                            user: @user,
                                            password: @password)
      @connection.logger = @transport_logger

      @session = @connection.shell(@shell)
      @session.run('$PSVersionTable.PSVersion')
      @logger.debug { "Opened session" }
    rescue ::WinRM::WinRMAuthorizationError
      raise Bolt::Node::ConnectError.new(
        "Authentication failed for #{@endpoint}",
        'AUTH_ERROR'
      )
    rescue StandardError => e
      raise Bolt::Node::ConnectError.new(
        "Failed to connect to #{@endpoint}: #{e.message}",
        'CONNECT_ERROR'
      )
    end

    def disconnect
      @session.close if @session
      @logger.debug { "Closed session" }
    end

    def shell_init
      return nil if @shell_initialized
      result = execute(<<-PS)

$ENV:PATH += ";${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\bin\\;" +
  "${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\sys\\ruby\\bin\\"
$ENV:RUBYLIB = "${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\puppet\\lib;" +
  "${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\facter\\lib;" +
  "${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\hiera\\lib;" +
  $ENV:RUBYLIB

function Invoke-Interpreter
{
  [CmdletBinding()]
  Param (
    [Parameter()]
    [String]
    $Path,

    [Parameter()]
    [String]
    $Arguments,

    [Parameter()]
    [Int32]
    $Timeout,

    [Parameter()]
    [String]
    $StdinInput = $Null
  )

  try
  {
    if (-not (Get-Command $Path -ErrorAction SilentlyContinue))
    {
      throw "Could not find executable '$Path' in ${ENV:PATH} on target node"
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo($Path, $Arguments)
    $startInfo.UseShellExecute = $false
    $startInfo.WorkingDirectory = Split-Path -Parent (Get-Command $Path).Path
    $startInfo.CreateNoWindow = $true
    if ($StdinInput) { $startInfo.RedirectStandardInput = $true }
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $stdoutHandler = { if (-not ([String]::IsNullOrEmpty($EventArgs.Data))) { $Host.UI.WriteLine($EventArgs.Data) } }
    $stderrHandler = { if (-not ([String]::IsNullOrEmpty($EventArgs.Data))) { $Host.UI.WriteErrorLine($EventArgs.Data) } }
    $invocationId = [Guid]::NewGuid().ToString()

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.EnableRaisingEvents = $true

    # https://msdn.microsoft.com/en-us/library/system.diagnostics.process.standarderror(v=vs.110).aspx#Anchor_2
    $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -Action $stdoutHandler
    $stderrEvent = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -Action $stderrHandler
    $exitedEvent = Register-ObjectEvent -InputObject $process -EventName 'Exited' -SourceIdentifier $invocationId

    $process.Start() | Out-Null

    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    if ($StdinInput)
    {
      $process.StandardInput.WriteLine($StdinInput)
      $process.StandardInput.Close()
    }

    # park current thread until the PS event is signaled upon process exit
    # OR the timeout has elapsed
    $waitResult = Wait-Event -SourceIdentifier $invocationId -Timeout $Timeout
    if (! $process.HasExited)
    {
      $Host.UI.WriteErrorLine("Process $Path did not complete in $Timeout seconds")
      return 1
    }

    return $process.ExitCode
  }
  catch
  {
    $Host.UI.WriteErrorLine($_)
    return 1
  }
  finally
  {
    @($stdoutEvent, $stderrEvent, $exitedEvent) |
      ? { $_ -ne $Null } |
      % { Unregister-Event -SourceIdentifier $_.Name }

    if ($process -ne $Null)
    {
      if (($process.Handle -ne $Null) -and (! $process.HasExited))
      {
        try { $process.Kill() } catch { $Host.UI.WriteErrorLine("Failed To Kill Process $Path") }
      }
      $process.Dispose()
    }
  }
}
PS
      if result.exit_code != 0
        raise BaseError.new("Could not initialize shell: #{result.stderr.string}", "SHELL_INIT_ERROR")
      end
      @shell_initialized = true
    end

    def execute(command, _ = {})
      result_output = Bolt::Node::Output.new

      @logger.debug { "Executing command: #{command}" }

      output = @session.run(command) do |stdout, stderr|
        result_output.stdout << stdout
        @logger.debug { "stdout: #{stdout}" }
        result_output.stderr << stderr
        @logger.debug { "stderr: #{stderr}" }
      end
      result_output.exit_code = output.exitcode
      if output.exitcode.zero?
        @logger.debug { "Command returned successfully" }
      else
        @logger.info { "Command failed with exit code #{output.exitcode}" }
      end
      result_output
    end

    # 10 minutes in seconds
    DEFAULT_EXECUTION_TIMEOUT = 10 * 60

    def execute_process(path = '', arguments = [], stdin = nil,
                        timeout = DEFAULT_EXECUTION_TIMEOUT)
      quoted_args = arguments.map do |arg|
        "'" + arg.gsub("'", "''") + "'"
      end.join(',')

      execute(<<-PS)
$quoted_array = @(
  #{quoted_args}
)

$invokeArgs = @{
  Path = "#{path}"
  Arguments = $quoted_array -Join ' '
  Timeout = #{timeout}
  #{stdin.nil? ? '' : "StdinInput = @'\n" + stdin + "\n'@"}
}

# winrm gem checks $? prior to using $LASTEXITCODE
# making it necessary to exit with the desired code to propagate status properly
exit $(Invoke-Interpreter @invokeArgs)
PS
    end

    VALID_EXTENSIONS = ['.ps1', '.rb', '.pp'].freeze

    PS_ARGS = %w[
      -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass
    ].freeze

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
      end
    end

    def _upload(source, destination)
      write_remote_file(source, destination)
      Bolt::Result.new
    # TODO: we should rely on the executor for this
    rescue StandardError => ex
      Bolt::Result.from_exception(ex)
    end

    def write_remote_file(source, destination)
      @logger.debug { "Uploading #{source} to #{destination}" }
      fs = ::WinRM::FS::FileManager.new(@connection)
      # TODO: raise FileError here if this fails
      fs.upload(source, destination)
    end

    def make_tempdir
      result = execute(<<-PS)
$parent = [System.IO.Path]::GetTempPath()
$name = [System.IO.Path]::GetRandomFileName()
$path = Join-Path $parent $name
New-Item -ItemType Directory -Path $path | Out-Null
$path
PS
      if result.exit_code != 0
        raise FileError.new("Could not make tempdir: #{result.stderr}", 'TEMPDIR_ERROR')
      end
      result.stdout.string.chomp
    end

    def with_remote_file(file)
      ext = File.extname(file)
      ext = VALID_EXTENSIONS.include?(ext) ? ext : '.ps1'
      file_base = File.basename(file, '.*')
      dir = make_tempdir
      dest = "#{dir}\\#{file_base}#{ext}"
      begin
        write_remote_file(file, dest)
        shell_init
        yield dest
      ensure
        execute(<<-PS)
Remove-Item -Force "#{dest}"
Remove-Item -Force "#{dir}"
PS
      end
    end

    def _run_command(command)
      output = execute(command)
      Bolt::CommandResult.from_output(output)
    # TODO: we should rely on the executor for this
    rescue StandardError => e
      Bolt::Result.from_exception(e)
    end

    def _run_script(script, arguments)
      @logger.info { "Running script '#{script}'" }
      with_remote_file(script) do |remote_path|
        if powershell_file?(remote_path)
          mapped_args = arguments.map do |a|
            "$invokeArgs.ArgumentList += @'\n#{a}\n'@"
          end.join("\n")
          output = execute(<<-PS)
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
          output = execute_process(path, args)
        end
        Bolt::CommandResult.from_output(output)
      end
    # TODO: we should rely on the executor for this
    rescue StandardError => e
      Bolt::Result.from_exception(e)
    end

    def _run_task(task, input_method, arguments)
      @logger.info { "Running task '#{task}'" }
      @logger.debug { "arguments: #{arguments}\ninput_method: #{input_method}" }

      if STDIN_METHODS.include?(input_method)
        stdin = JSON.dump(arguments)
      end

      if ENVIRONMENT_METHODS.include?(input_method)
        arguments.each do |(arg, val)|
          cmd = "[Environment]::SetEnvironmentVariable('PT_#{arg}', '#{val}')"
          result = execute(cmd)
          if result.exit_code != 0
            raise EnvironmentVarError(var, value)
          end
        end
      end

      with_remote_file(task) do |remote_path|
        if powershell_file?(remote_path) && stdin.nil?
          # NOTE: cannot redirect STDIN to a .ps1 script inside of PowerShell
          # must create new powershell.exe process like other interpreters
          # fortunately, using PS with stdin input_method should never happen
          output = execute("try { &""#{remote_path}"" } catch { exit 1 }")
        else
          path, args = *process_from_extension(remote_path)
          output = execute_process(path, args, stdin)
        end
        Bolt::TaskResult.from_output(output)
      end
    # TODO: we should rely on the executor for this
    rescue StandardError => e
      Bolt::Result.from_exception(e)
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
