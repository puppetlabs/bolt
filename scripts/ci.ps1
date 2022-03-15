$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

function Set-CACert
{
  $uri = 'https://curl.haxx.se/ca/cacert.pem'
  $CACertFile = Join-Path -Path $ENV:AppData -ChildPath 'RubyCACert.pem'

  $retryArgs = @{
    SuccessMessage = "Succeeded in downloading CA bundle from $uri"
    FailMessage    = "Failed to download CA bundle from $uri"
    Retries        = 5
    Timeout        = 1
    Script         = {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $CACertFile | Out-Null
    }
  }

  # only download CA file if not present - throw on failures
  If (-Not (Test-Path -Path $CACertFile)) { Invoke-ScriptBlockWithRetry @retryArgs }

  Write-Information "Setting CA Certificate store set to $CACertFile.."
  $ENV:SSL_CERT_FILE = $CACertFile
  [System.Environment]::SetEnvironmentVariable('SSL_CERT_FILE', $CACertFile, [System.EnvironmentVariableTarget]::Machine)
}

function Install-Puppetfile
{
  Set-CACert

  # Forge connections may fail intermittently
  $retryArgs = @{
    SuccessMessage = 'Succeeded in installing Puppetfile'
    FailMessage    = 'Failed to install required modules from Forge'
    Retries        = 10
    Timeout        = 2
    Script         = { bundle exec r10k puppetfile install }
  }

  Invoke-ScriptBlockWithRetry @retryArgs
}

function New-RandomPassword
{
  Add-Type -AssemblyName System.Web
  "&aA4" + [System.Web.Security.Membership]::GeneratePassword(10, 3)
}

function New-LocalAdmin($userName, $password)
{
  $userArgs = @{
    Name     = $userName
    Password = (ConvertTo-SecureString -String $password -Force -AsPlainText)
  }

  $user = New-LocalUser @userArgs
  Write-Information ($user | Format-List | Out-String)
  Add-LocalGroupMember -Group 'Remote Management Users' -Member $user
  Add-LocalGroupMember -Group Administrators -Member $user
}

function Install-Certificate($path, $password)
{
  $importArgs = @{
    FilePath          = $path
    CertStoreLocation = 'cert:\\LocalMachine\\My'
    Password          = (ConvertTo-SecureString -String $password -Force -AsPlainText)
  }

  return (Import-PfxCertificate @importArgs)
}

function Grant-WinRMHttpsAccess($certThumbprint)
{
  $winRMArgs = @{
    ResourceURI = 'winrm/config/Listener'
    SelectorSet = @{ Address = '*'; Transport = 'HTTPS'; }
    ValueSet    = @{ Hostname = 'boltserver'; CertificateThumbprint = $certThumbprint }
  }
  $instance = Set-WSManInstance @winRMArgs
  Write-Information ($instance | Format-List | Out-String)
}

function Set-WinRMHostConfiguration
{
  # configure WinRM to use cert.pfx for SSL
  $cert = Install-Certificate -Path 'spec/fixtures/ssl/cert.pfx' -Password 'bolt'
  Write-Information ($cert | Format-List | Out-String)
  Grant-WinRMHttpsAccess -CertThumbprint $cert.Thumbprint
}

function Invoke-ScriptBlockWithRetry([ScriptBlock]$script, $failMessage, $successMessage, $retries = 15, $timeout = 1)
{
  $retried = 0

  Do
  {
    try {
      $script.Invoke()
      Write-Information "$successMessage after $($retried + 1) attempt(s)"
      return $true
    }
    catch
    {
      $retried++
      Start-Sleep -Seconds $timeout
    }
  } While ($retried -lt $retries)

  throw "ERROR: $failMessage in $retried retries`n$($Error[0])"

}

function Test-WinRMConfiguration($userName, $password, $retries = 15, $timeout = 1)
{
  $retryArgs = @{
    FailMessage    = 'Failed to establish WinRM connection over SSL'
    SuccessMessage = "Successfully established WinRM connection with $userName"
    Retries        = $retries
    Timeout        = $timeout
    Script         = {
      $pass = ConvertTo-SecureString $password -AsPlainText -Force
      $sessionArgs = @{
        ComputerName = 'localhost'
        Credential   = New-Object System.Management.Automation.PSCredential ($userName, $pass)
        UseSSL       = $true
        SessionOption = New-PSSessionOption -SkipRevocationCheck -SkipCACheck
      }

      if (New-PSSession @sessionArgs) { return $true }
    }
  }

  Invoke-ScriptBlockWithRetry @retryArgs
}

function Test-WinRMConfigurationNoSSL($userName, $password, $retries = 15, $timeout = 1)
{
  $retryArgs = @{
    FailMessage    = 'Failed to establish WinRM connection over SSL'
    SuccessMessage = "Successfully established WinRM connection with $userName"
    Retries        = $retries
    Timeout        = $timeout
    Script         = {
      $pass = ConvertTo-SecureString $password -AsPlainText -Force
      $sessionArgs = @{
        ComputerName = 'localhost'
        Credential   = New-Object System.Management.Automation.PSCredential ($userName, $pass)
        UseSSL       = $false
        SessionOption = New-PSSessionOption -SkipRevocationCheck -SkipCACheck
        Port         = 5985
      }

      if (New-PSSession @sessionArgs) { return $true }
    }
  }

  Invoke-ScriptBlockWithRetry @retryArgs
}

# Ensure Puppet Ruby 5 / 6 takes precedence over system Ruby
function Set-ActiveRubyFromPuppet
{
  # https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md
  $path = @(
    "${ENV:ProgramFiles}\Puppet Labs\Puppet\sys\ruby\bin",
    "${ENV:ProgramFiles}\Puppet Labs\Puppet\puppet\bin",
    $ENV:Path
  ) -join ';'

  [System.Environment]::SetEnvironmentVariable('Path', $path, [System.EnvironmentVariableTarget]::Machine)
}

$Pass = New-RandomPassword
$User = @{ UserName = $ENV:BOLT_WINRM_USER; Password = $Pass }
New-LocalAdmin @User
Enable-PSRemoting
Set-WSManQuickConfig -Force
Set-WinRMHostConfiguration
Test-WinRMConfiguration @User | Out-Null
Test-WinRMConfigurationNoSSL @User | Out-Null
Add-Content -Path $ENV:GITHUB_ENV -Value "BOLT_WINRM_PASSWORD=$pass"
