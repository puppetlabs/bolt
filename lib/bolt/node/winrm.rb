require 'winrm'
require 'winrm-fs'
require 'bolt/result'

module Bolt
  class WinRM < Node
    def initialize(host, port, user, password, shell: :powershell, **kwargs)
      super(host, port, user, password, **kwargs)

      @shell = shell
      @endpoint = "http://#{host}:#{port}/wsman"
      options = { endpoint: @endpoint,
                  user: @user,
                  password: @password }
      if @timeout then
        options[:receive_timeout] = @timeout
        options[:operation_timeout] = @timeout
      end
      @connection = ::WinRM::Connection.new(options)
      @connection.logger = @transport_logger
    end

    def connect
      @session = @connection.shell(@shell)
      @logger.debug { "Opened session" }
    end

    def disconnect
      @session.close if @session
      @logger.debug { "Closed session" }
    end

    def shell_init
      return Bolt::Node::Success.new if @shell_initialized
      result = execute(<<-PS)

$ENV:PATH += ";${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\sys\\ruby\\bin\\"
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

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo($Path, $Arguments)
  $startInfo.UseShellExecute = $false
  if ($StdinInput) { $startInfo.RedirectStandardInput = $true }
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  try
  {
    $process = [System.Diagnostics.Process]::Start($startInfo)
  }
  catch
  {
    Write-Error $_
    return 1
  }

  if ($StdinInput)
  {
    $process.StandardInput.WriteLine($StdinInput)
    $process.StandardInput.Close()
  }

  # streams must have .ReadToEnd() called prior to process .WaitForExit()
  # to prevent deadlocks per MSDN
  # https://msdn.microsoft.com/en-us/library/system.diagnostics.process.standarderror(v=vs.110).aspx#Anchor_2
  $process.StandardOutput.ReadToEnd() | Out-Host
  $stderr = $process.StandardError.ReadToEnd()
  if ($stderr) { Write-Error $stderr }
  $process.WaitForExit($Timeout) | Out-Null

  return $process.ExitCode
}
PS
      @shell_initialized = true

      result
    end

    def execute(command, _ = {})
      result_output = Bolt::Node::ResultOutput.new

      @logger.debug { "Executing command: #{command}" }

      output = @session.run(command) do |stdout, stderr|
        result_output.stdout << stdout
        @logger.debug { "stdout: #{stdout}" }
        result_output.stderr << stderr
        @logger.debug { "stderr: #{stderr}" }
      end
      if output.exitcode.zero?
        @logger.debug { "Command returned successfully" }
        Bolt::Node::Success.new(result_output.stdout.string, result_output)
      else
        @logger.info { "Command failed with exit code #{output.exitcode}" }
        Bolt::Node::Failure.new(output.exitcode, result_output)
      end
    end

    # 10 minutes in milliseconds
    DEFAULT_EXECUTION_TIMEOUT = 10 * 60 * 1000

    def execute_process(path = '', arguments = '', stdin = nil,
                        timeout_ms = DEFAULT_EXECUTION_TIMEOUT)
      execute(<<-PS)
$invokeArgs = @{
  Path = "#{path}"
  Arguments = "#{arguments.gsub('"', '""')}"
  Timeout = #{timeout_ms}
  #{stdin.nil? ? '' : "StdinInput = @'\n" + stdin + "\n'@"}
}

# winrm gem relies on $LASTEXITCODE
$LASTEXITCODE = Invoke-Interpreter @invokeArgs
PS
    end

    VALID_EXTENSIONS = ['.ps1', '.rb'].freeze

    PS_ARGS =
      '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'.freeze

    def process_from_extension(path)
      case Pathname(path).extname.downcase
      when '.rb'
        [
          'ruby.exe',
          "-S \"#{path}\""
        ]
      when '.ps1'
        [
          'powershell.exe',
          "#{PS_ARGS} -File \"#{path}\""
        ]
      end
    end

    def _upload(source, destination)
      @logger.debug { "Uploading #{source} to #{destination}" }
      fs = ::WinRM::FS::FileManager.new(@connection)
      fs.upload(source, destination)
      Bolt::Node::Success.new
    rescue StandardError => ex
      Bolt::Node::ExceptionFailure.new(ex)
    end

    def make_tempdir
      result = execute(<<-PS)
$parent = [System.IO.Path]::GetTempPath()
$name = [System.IO.Path]::GetRandomFileName()
$path = Join-Path $parent $name
New-Item -ItemType Directory -Path $path | Out-Null
$path
PS
      result.then { |stdout| Bolt::Node::Success.new(stdout.chomp) }
    end

    def with_remote_file(file)
      dest = ''
      dir = ''
      result = nil

      make_tempdir.then do |value|
        dir = value
        ext = File.extname(file)
        ext = VALID_EXTENSIONS.include?(ext) ? ext : '.ps1'
        dest = "#{dir}\\#{File.basename(file, '.*')}#{ext}"
        Bolt::Node::Success.new
      end.then do
        _upload(file, dest)
      end.then do
        shell_init
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

    def _run_command(command)
      execute(command)
    end

    def _run_script(script)
      @logger.info { "Running script '#{script}'" }
      with_remote_file(script) do |remote_path|
        args = "#{PS_ARGS} -File \"#{remote_path}\""
        execute_process('powershell.exe', args)
      end
    end

    def _run_task(task, input_method, arguments)
      @logger.info { "Running task '#{task}'" }
      @logger.debug { "arguments: #{arguments}\ninput_method: #{input_method}" }

      if STDIN_METHODS.include?(input_method)
        stdin = JSON.dump(arguments)
      end

      if ENVIRONMENT_METHODS.include?(input_method)
        arguments.reduce(Bolt::Node::Success.new) do |result, (arg, val)|
          result.then do
            cmd = "[Environment]::SetEnvironmentVariable('PT_#{arg}', '#{val}')"
            execute(cmd)
          end
        end
      else
        Bolt::Node::Success.new
      end.then do
        with_remote_file(task) do |remote_path|
          execute_process(*process_from_extension(remote_path), stdin)
        end
      end
    end
  end
end
