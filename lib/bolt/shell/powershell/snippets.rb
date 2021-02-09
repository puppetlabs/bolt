# frozen_string_literal: true

module Bolt
  class Shell
    class Powershell < Shell
      module Snippets
        class << self
          def execute_process(command)
            <<~PS
            if ([Console]::InputEncoding -eq [System.Text.Encoding]::UTF8) {
              [Console]::InputEncoding = New-Object System.Text.UTF8Encoding $False
            }
            if ([Console]::OutputEncoding -eq [System.Text.Encoding]::UTF8) {
              [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $False
            }
            $OutputEncoding = [Console]::OutputEncoding
            #{command}
            if (-not $? -and ($LASTEXITCODE -eq $null)) { exit 1 }
            exit $LASTEXITCODE
            PS
          end

          def exit_with_code(command)
            <<~PS
            #{command}
            if (-not $? -and ($LASTEXITCODE -eq $null)) { exit 1 }
            exit $LASTEXITCODE
            PS
          end

          def make_tmpdir(parent)
            <<~PS
            $parent = #{parent}
            $name = [System.IO.Path]::GetRandomFileName()
            $path = Join-Path $parent $name -ErrorAction Stop
            New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
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

          def append_ps_module_path(directory)
            <<~PS
            $env:PSModulePath += ";#{directory}"
            PS
          end

          def ps_task(path, arguments)
            <<~PS
            $private:tempArgs = Get-ContentAsJson (
              [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('#{Base64.encode64(JSON.dump(arguments))}'))
            )
            $allowedArgs = (Get-Command "#{path}").Parameters.Keys
            $private:taskArgs = @{}
            $private:tempArgs.Keys | ? { $allowedArgs -contains $_ } | % { $private:taskArgs[$_] = $private:tempArgs[$_] }
            try {
              & "#{path}" @taskArgs
            } catch {
              $Host.UI.WriteErrorLine("[$($_.FullyQualifiedErrorId)] Exception $($_.InvocationInfo.PositionMessage).`n$($_.Exception.Message)");
              exit 1;
            }
            PS
          end

          def try_catch(command)
            %(try { & "#{command}" } catch { Write-Error $_.Exception; exit 1 })
          end

          def shell_init
            <<~PS
            $installRegKey = Get-ItemProperty -Path "HKLM:\\Software\\Puppet Labs\\Puppet" -ErrorAction 0
            if(![string]::IsNullOrEmpty($installRegKey.RememberedInstallDir64)){
              $boltBaseDir = $installRegKey.RememberedInstallDir64
            }elseif(![string]::IsNullOrEmpty($installRegKey.RememberedInstallDir)){
              $boltBaseDir = $installRegKey.RememberedInstallDir
            }else{
              $boltBaseDir = "${ENV:ProgramFiles}\\Puppet Labs\\Puppet"
            }

            $ENV:PATH += ";${boltBaseDir}\\bin\\;" +
            "${boltBaseDir}\\puppet\\bin;" +
            "${boltBaseDir}\\sys\\ruby\\bin\\"
            $ENV:RUBYLIB = "${boltBaseDir}\\puppet\\lib;" +
            "${boltBaseDir}\\facter\\lib;" +
            "${boltBaseDir}\\hiera\\lib;" +
            $ENV:RUBYLIB

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
          
            $Text | ConvertFrom-Json | ConvertFrom-PSCustomObject
            }
            PS
          end
        end
      end
    end
  end
end
