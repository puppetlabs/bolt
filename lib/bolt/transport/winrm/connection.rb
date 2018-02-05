require 'bolt/node/errors'
require 'bolt/node/output'

module Bolt
  module Transport
    class WinRM
      class Connection
        attr_reader :logger, :password, :connect_timeout, :target

        def initialize(target)
          @target = target

          transport_conf = target.options
          @user = @target.user
          @password = @target.password
          @cacert = transport_conf[:cacert]
          @ssl = transport_conf[:ssl]
          @connect_timeout = transport_conf[:connect_timeout]
          @tmpdir = transport_conf[:tmpdir]
          @extensions = DEFAULT_EXTENSIONS.to_set.merge(transport_conf[:extensions] || [])

          @logger = Logging.logger[@target.host]
        end

        def uri
          @target.uri
        end

        STDIN_METHODS       = %w[both stdin].freeze
        ENVIRONMENT_METHODS = %w[both environment].freeze

        HTTP_PORT = 5985
        HTTPS_PORT = 5986

        def port
          default_port = @ssl ? HTTPS_PORT : HTTP_PORT
          @target.port || default_port
        end

        def connect
          if @ssl
            scheme = 'https'
            transport = :ssl
          else
            scheme = 'http'
            transport = :negotiate
          end
          endpoint = "#{scheme}://#{@target.host}:#{port}/wsman"
          options = { endpoint: endpoint,
                      user: @user,
                      password: @password,
                      retry_limit: 1,
                      transport: transport,
                      ca_trust_path: @cacert }

          Timeout.timeout(@connect_timeout) do
            @connection = ::WinRM::Connection.new(options)
            transport_logger = Logging.logger[::WinRM]
            transport_logger.level = :warn
            @connection.logger = transport_logger

            @session = @connection.shell(:powershell)
            @session.run('$PSVersionTable.PSVersion')
            @logger.debug { "Opened session" }
          end
        rescue Timeout::Error
          # If we're using the default port with SSL, a timeout probably means the
          # host doesn't support SSL.
          if @ssl && port == HTTPS_PORT
            theres_your_problem = "\nUse --no-ssl if this host isn't configured to use SSL for WinRM"
          end
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{@connect_timeout} seconds connecting to #{endpoint}#{theres_your_problem}",
            'CONNECT_ERROR'
          )
        rescue ::WinRM::WinRMAuthorizationError
          raise Bolt::Node::ConnectError.new(
            "Authentication failed for #{endpoint}",
            'AUTH_ERROR'
          )
        rescue OpenSSL::SSL::SSLError => e
          # If we're using SSL with the default non-SSL port, mention that as a likely problem
          if @ssl && port == HTTP_PORT
            theres_your_problem = "\nAre you using SSL to connect to a non-SSL port?"
          end
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{endpoint}: #{e.message}#{theres_your_problem}",
            "CONNECT_ERROR"
          )
        rescue StandardError => e
          raise Bolt::Node::ConnectError.new(
            "Failed to connect to #{endpoint}: #{e.message}",
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

Add-Type -AssemblyName System.ServiceModel.Web, System.Runtime.Serialization
$utf8 = [System.Text.Encoding]::UTF8

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

function Write-Stream {
  PARAM(
    [Parameter(Position=0)] $stream,
    [Parameter(ValueFromPipeline=$true)] $string
  )
  PROCESS {
    $bytes = $utf8.GetBytes($string)
    $stream.Write( $bytes, 0, $bytes.Length )
  }
}

function Convert-JsonToXml {
  PARAM([Parameter(ValueFromPipeline=$true)] [string[]] $json)
  BEGIN {
    $mStream = New-Object System.IO.MemoryStream
  }
  PROCESS {
    $json | Write-Stream -Stream $mStream
  }
  END {
    $mStream.Position = 0
    try {
      $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($mStream,[System.Xml.XmlDictionaryReaderQuotas]::Max)
      $xml = New-Object Xml.XmlDocument
      $xml.Load($jsonReader)
      $xml
    } finally {
      $jsonReader.Close()
      $mStream.Dispose()
    }
  }
}

Function ConvertFrom-Xml {
  [CmdletBinding(DefaultParameterSetName="AutoType")]
  PARAM(
    [Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=1)] [Xml.XmlNode] $xml,
    [Parameter(Mandatory=$true,ParameterSetName="ManualType")] [Type] $Type,
    [Switch] $ForceType
  )
  PROCESS{
    if (Get-Member -InputObject $xml -Name root) {
      return $xml.root.Objects | ConvertFrom-Xml
    } elseif (Get-Member -InputObject $xml -Name Objects) {
      return $xml.Objects | ConvertFrom-Xml
    }
    $propbag = @{}
    foreach ($name in Get-Member -InputObject $xml -MemberType Properties | Where-Object{$_.Name -notmatch "^__|type"} | Select-Object -ExpandProperty name) {
      Write-Debug "$Name Type: $($xml.$Name.type)" -Debug:$false
      $propbag."$Name" = Convert-Properties $xml."$name"
    }
    if (!$Type -and $xml.HasAttribute("__type")) { $Type = $xml.__Type }
    if ($ForceType -and $Type) {
      try {
        $output = New-Object $Type -Property $propbag
      } catch {
        $output = New-Object PSObject -Property $propbag
        $output.PsTypeNames.Insert(0, $xml.__type)
      }
    } elseif ($propbag.Count -ne 0) {
      $output = New-Object PSObject -Property $propbag
      if ($Type) {
        $output.PsTypeNames.Insert(0, $Type)
      }
    }
    return $output
  }
}

Function Convert-Properties {
  PARAM($InputObject)
  switch ($InputObject.type) {
    "object" {
      return (ConvertFrom-Xml -Xml $InputObject)
    }
    "string" {
      $MightBeADate = $InputObject.get_InnerText() -as [DateTime]
      ## Strings that are actually dates (*grumble* JSON is crap)
      if ($MightBeADate -and $propbag."$Name" -eq $MightBeADate.ToString("G")) {
        return $MightBeADate
      } else {
        return $InputObject.get_InnerText()
      }
    }
    "number" {
      $number = $InputObject.get_InnerText()
      if ($number -eq ($number -as [int])) {
        return $number -as [int]
      } elseif ($number -eq ($number -as [double])) {
        return $number -as [double]
      } else {
        return $number -as [decimal]
      }
    }
    "boolean" {
      return [bool]::parse($InputObject.get_InnerText())
    }
    "null" {
      return $null
    }
    "array" {
      [object[]]$Items = $(foreach( $item in $InputObject.GetEnumerator() ) {
        Convert-Properties $item
      })
      return $Items
    }
    default {
      return $InputObject
    }
  }
}

Function ConvertFrom-Json2 {
  [CmdletBinding()]
  PARAM(
    [Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=1)] [string] $InputObject,
    [Parameter(Mandatory=$true)] [Type] $Type,
    [Switch] $ForceType
  )
  PROCESS {
    $null = $PSBoundParameters.Remove("InputObject")
    [Xml.XmlElement]$xml = (Convert-JsonToXml $InputObject).Root
    if ($xml) {
      if ($xml.Objects) {
        $xml.Objects.Item.GetEnumerator() | ConvertFrom-Xml @PSBoundParameters
      } elseif ($xml.Item -and $xml.Item -isnot [System.Management.Automation.PSParameterizedProperty]) {
        $xml.Item | ConvertFrom-Xml @PSBoundParameters
      } else {
        $xml | ConvertFrom-Xml @PSBoundParameters
      }
    } else {
      Write-Error "Failed to parse JSON with JsonReader" -Debug:$false
    }
  }
}

function ConvertFrom-PSCustomObject
{
  PARAM([Parameter(ValueFromPipeline = $true)] $InputObject)
  PROCESS {
    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
      $collection = @(
        foreach ($object in $InputObject) { ConvertFrom-PSCustomObject $object }
      )

      $collection
    } elseif ($InputObject -is [System.Management.Automation.PSCustomObject]) {
      $hash = @{}
      foreach ($property in $InputObject.PSObject.Properties) {
        $hash[$property.Name] = ConvertFrom-PSCustomObject $property.Value
      }

      $hash
    } else {
      $InputObject
    }
  }
}

function Get-ContentAsJson
{
  [CmdletBinding()]
  PARAM(
    [Parameter(Mandatory = $true)] $Text,
    [Parameter(Mandatory = $false)] [Text.Encoding] $Encoding = [Text.Encoding]::UTF8
  )

  # using polyfill cmdlet on PS2, so pass type info
  if ($PSVersionTable.PSVersion -lt [Version]'3.0') {
    $Text | ConvertFrom-Json2 -Type PSObject | ConvertFrom-PSCustomObject
  } else {
    $Text | ConvertFrom-Json | ConvertFrom-PSCustomObject
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
        private :execute

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

        DEFAULT_EXTENSIONS = ['.ps1', '.rb', '.pp'].freeze

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
          else
            # Run the script via cmd, letting Windows extension handling determine how
            [
              'cmd.exe',
              ['/c', "\"#{path}\""]
            ]
          end
        end

        def upload(source, destination, _options = nil)
          write_remote_file(source, destination)
          Bolt::Result.for_upload(@target, source, destination)
        end

        def write_remote_file(source, destination)
          fs = ::WinRM::FS::FileManager.new(@connection)
          # TODO: raise FileError here if this fails
          fs.upload(source, destination)
        end

        def make_tempdir
          find_parent = @tmpdir ? "\"#{@tmpdir}\"" : '[System.IO.Path]::GetTempPath()'
          result = execute(<<-PS)
$parent = #{find_parent}
$name = [System.IO.Path]::GetRandomFileName()
$path = Join-Path $parent $name
New-Item -ItemType Directory -Path $path | Out-Null
$path
PS
          if result.exit_code != 0
            raise Bolt::Node::FileError.new("Could not make tempdir: #{result.stderr}", 'TEMPDIR_ERROR')
          end
          result.stdout.string.chomp
        end

        def with_remote_file(file)
          ext = File.extname(file)
          unless @extensions.include?(ext)
            raise Bolt::Node::FileError.new("File extension #{ext} is not enabled, "\
                                "to run it please add to 'winrm: extensions'", 'FILETYPE_ERROR')
          end
          file_base = File.basename(file)
          dir = make_tempdir
          dest = "#{dir}\\#{file_base}"
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

        def run_command(command, _options = nil)
          output = execute(command)
          Bolt::Result.for_command(@target, output.stdout.string, output.stderr.string, output.exit_code)
        end

        def run_script(script, arguments, _options = nil)
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
            Bolt::Result.for_command(@target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end

        def run_task(task, input_method, arguments, _options = nil)
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
            output =
              if powershell_file?(remote_path) && stdin.nil?
                # NOTE: cannot redirect STDIN to a .ps1 script inside of PowerShell
                # must create new powershell.exe process like other interpreters
                # fortunately, using PS with stdin input_method should never happen
                if input_method == 'powershell'
                  execute(<<-PS)
$private:taskArgs = Get-ContentAsJson (
  $utf8.GetString([System.Convert]::FromBase64String('#{Base64.encode64(JSON.dump(arguments))}'))
)
try { & "#{remote_path}" @taskArgs } catch { exit 1 }
              PS
                else
                  execute(%(try { & "#{remote_path}" } catch { exit 1 }))
                end
              else
                path, args = *process_from_extension(remote_path)
                execute_process(path, args, stdin)
              end
            Bolt::Result.for_task(@target, output.stdout.string,
                                  output.stderr.string,
                                  output.exit_code)
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
end
