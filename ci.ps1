$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

function Set-CACert
{
  $CACertFile = Join-Path -Path $ENV:AppData -ChildPath 'RubyCACert.pem'

  If (-Not (Test-Path -Path $CACertFile)) {
    Write-Information "Downloading CA Cert bundle.."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://curl.haxx.se/ca/cacert.pem' -UseBasicParsing -OutFile $CACertFile | Out-Null
  }

  Write-Information "Setting CA Certificate store set to $CACertFile.."
  $ENV:SSL_CERT_FILE = $CACertFile
  [System.Environment]::SetEnvironmentVariable('SSL_CERT_FILE', $CACertFile, [System.EnvironmentVariableTarget]::Machine)
}

function Install-Puppetfile
{
  Set-CACert
  bundle exec r10k puppetfile install
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
    SelectorSet = @{ Address = '*'; Transport = 'HTTPS' }
    ValueSet    = @{ Hostname = 'localhost'; CertificateThumbprint = $certThumbprint }
  }
  $instance = New-WSManInstance @winRMArgs
  Write-Information ($instance | Format-List | Out-String)
}

function Set-WinRMHostConfiguration
{
  # configure WinRM to use resources/cert.pfx for SSL
  $cert = Install-Certificate -Path 'resources/cert.pfx' -Password 'bolt'
  Write-Information ($cert | Format-List | Out-String)
  Grant-WinRMHttpsAccess -CertThumbprint $cert.Thumbprint
}

function Test-WinRMConfiguration($userName, $password, $retries = 15, $timeout = 1)
{
  $retried = 0

  Do
  {
    try {
      $pass = ConvertTo-SecureString $password -AsPlainText -Force
      $sessionArgs = @{
        ComputerName = 'localhost'
        Credential   = New-Object System.Management.Automation.PSCredential ($userName, $pass)
        UseSSL       = $true
        SessionOption = New-PSSessionOption -SkipRevocationCheck -SkipCACheck
      }

      $session = New-PSSession @sessionArgs
      if ($session)
      {
        Write-Information "Successfully established WinRM connection with $userName after $($retried + 1) attempt(s)"
        return $true
      }
    }
    catch
    {
      $retried++
      Start-Sleep -Seconds $timeout
    }
  } While ($retried -lt $retries)

  throw "Failed to establish WinRM connection over SSL in $retries retries`n$($Error[0])"
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
