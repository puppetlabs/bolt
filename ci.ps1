$ErrorActionPreference = 'Stop'

function Set-CACert
{
  $CACertFile = Join-Path -Path $ENV:AppData -ChildPath 'RubyCACert.pem'

  If (-Not (Test-Path -Path $CACertFile)) {
    "Downloading CA Cert bundle.."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://curl.haxx.se/ca/cacert.pem' -UseBasicParsing -OutFile $CACertFile | Out-Null
  }

  "Setting CA Certificate store set to $CACertFile.."
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
  $user | Format-List
  Add-LocalGroupMember -Group 'Remote Management Users' -Member $user
  Add-LocalGroupMember -Group Administrators -Member $user
}

function Set-WinRMHostConfiguration
{
  # configure WinRM to use resources/cert.pfx for SSL
  ($cert = Import-PfxCertificate -FilePath resources/cert.pfx -CertStoreLocation cert:\\LocalMachine\\My -Password (ConvertTo-SecureString -String bolt -Force -AsPlainText)) | Format-List
  New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address='*';Transport='HTTPS'} -ValueSet @{Hostname='localhost';CertificateThumbprint=$cert.Thumbprint} | Format-List
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
