module Bolt
  class Shell
    class Powershell < Shell
      module Snippets
        def execute_process(command)
          <<~PS
          $OutputEncoding = [Console]::OutputEncoding
          #{exec_cmd}
          if (-not $? -and ($LASTEXITCODE -eq $null)) { exit 1 }
          exit $LASTEXITCODE
          PS
        end

        def make_tempdir(parent)
          <<~PS
          $parent = #{parent}
          $name = [System.IO.Path]::GetRandomFileName()
          $path = Join-Path $parent $name
          New-Item -ItemType Directory -Path $path | Out-Null
          $path
          PS
        end

        def rmdir(dir)
          <<~PS
          Remove-Item -Force -Recurse -Path "#{dir}"
          PS
        end

        def run_script(arguments, script_path)
          build_arg_list = arguments.map do |a|
            "$invokeArgs.ArgumentList += @'\n#{a}\n'@"
          end.join("\n")
          <<~PS
          $invokeArgs = @{
            ScriptBlock = (Get-Command "#{script_path}").ScriptBlock
            ArgumentList = @()
          }
          #{build_arg_list}

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
        end

        def ps_task(path, arguments)
          <<~PS
          $private:tempArgs = Get-ContentAsJson (
            $utf8.GetString([System.Convert]::FromBase64String('#{Base64.encode64(JSON.dump(arguments))}'))
          )
          $allowedArgs = (Get-Command "#{path}").Parameters.Keys
          $private:taskArgs = @{}
          $private:tempArgs.Keys | ? { $allowedArgs -contains $_ } | % { $private:taskArgs[$_] = $private:tempArgs[$_] }
          try { & "#{path}" @taskArgs } catch { Write-Error $_.Exception; exit 1 }
          PS
        end

        def try_catch(command)
          %(try { & "#{command}" } catch { Write-Error $_.Exception; exit 1 })
        end

        def shell_init
          <<~PS
          $ENV:PATH += ";${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\bin\\;" +
          "${ENV:ProgramFiles}\\Puppet Labs\\Puppet\\puppet\\bin;" +
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
            foreach ($name in Get-Member -InputObject $xml -MemberType Properties | Where-Object{$_.Name -notmatch "^(__.*|type)$"} | Select-Object -ExpandProperty name) {
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
        end
      end
    end
  end
end
