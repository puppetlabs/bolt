# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/node/output'

module Bolt
  module Transport
    class WinRM < Base
      class Connection
        attr_reader :logger, :target

        DEFAULT_EXTENSIONS = ['.ps1', '.rb', '.pp'].freeze

        def initialize(target, transport_logger)
          @target = target

          default_port = target.options['ssl'] ? HTTPS_PORT : HTTP_PORT
          @port = @target.port || default_port
          @user = @target.user

          # Accept a single entry or a list, ensure each is prefixed with '.'
          extensions = [target.options['extensions'] || []].flatten.map { |ext| ext[0] != '.' ? '.' + ext : ext }
          @extensions = DEFAULT_EXTENSIONS.to_set.merge(extensions)

          @logger = Logging.logger[@target.host]
          @transport_logger = transport_logger
        end

        HTTP_PORT = 5985
        HTTPS_PORT = 5986

        def connect
          if target.options['ssl']
            scheme = 'https'
            transport = :ssl
          else
            scheme = 'http'
            transport = :negotiate
          end
          endpoint = "#{scheme}://#{target.host}:#{@port}/wsman"
          options = { endpoint: endpoint,
                      user: @user,
                      password: target.password,
                      retry_limit: 1,
                      transport: transport,
                      ca_trust_path: target.options['cacert'],
                      no_ssl_peer_verification: !target.options['ssl-verify'] }

          Timeout.timeout(target.options['connect-timeout']) do
            @connection = ::WinRM::Connection.new(options)
            @connection.logger = @transport_logger

            @session = @connection.shell(:powershell)
            @session.run('$PSVersionTable.PSVersion')
            @logger.debug { "Opened session" }
          end
        rescue Timeout::Error
          # If we're using the default port with SSL, a timeout probably means the
          # host doesn't support SSL.
          if target.options['ssl'] && @port == HTTPS_PORT
            the_problem = "\nUse --no-ssl if this host isn't configured to use SSL for WinRM"
          end
          raise Bolt::Node::ConnectError.new(
            "Timeout after #{target.options['connect-timeout']} seconds connecting to #{endpoint}#{the_problem}",
            'CONNECT_ERROR'
          )
        rescue ::WinRM::WinRMAuthorizationError
          raise Bolt::Node::ConnectError.new(
            "Authentication failed for #{endpoint}",
            'AUTH_ERROR'
          )
        rescue OpenSSL::SSL::SSLError => e
          # If we're using SSL with the default non-SSL port, mention that as a likely problem
          if target.options['ssl'] && @port == HTTP_PORT
            theres_your_problem = "\nAre you using SSL to connect to a non-SSL port?"
          end
          if target.options['ssl-verify'] && e.message.include?('certificate verify failed')
            theres_your_problem = "\nIs the remote host using a self-signed SSL"\
                                  "certificate? Use --no-ssl-verify to disable "\
                                  "remote host SSL verification."
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
          @session&.close
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

        def execute(command)
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
        rescue StandardError
          @logger.debug { "Command aborted" }
          raise
        end

        def execute_process(path = '', arguments = [], stdin = nil)
          quoted_args = arguments.map do |arg|
            "'" + arg.gsub("'", "''") + "'"
          end.join(' ')

          exec_cmd =
            if stdin.nil?
              "& #{path} #{quoted_args}"
            else
              "@'\n#{stdin}\n'@ | & #{path} #{quoted_args}"
            end
          execute(<<-PS)
$OutputEncoding = [Console]::OutputEncoding
#{exec_cmd}
if (-not $? -and ($LASTEXITCODE -eq $null)) { exit 1 }
exit $LASTEXITCODE
PS
        end

        def write_remote_file(source, destination)
          fs = ::WinRM::FS::FileManager.new(@connection)
          # TODO: raise FileError here if this fails
          fs.upload(source, destination)
        end

        def make_tempdir
          find_parent = target.options['tmpdir'] ? "\"#{target.options['tmpdir']}\"" : '[System.IO.Path]::GetTempPath()'
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
      end
    end
  end
end
