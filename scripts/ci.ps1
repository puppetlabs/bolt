$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

# Remove the current NAT network and pre-create the network for docker-compose
Write-Output "Removing current NAT network..."
Remove-NetNat -Confirm:$false

# Create the new network
Write-Output "Creating spec_default docker network..."
& cmd /c --% docker network create spec_default --driver nat 2>&1

Enable-PSRemoting
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
winrm "set" "winrm/config/client/auth" "@{Kerberos=`"false`"}"
winrm "set" "winrm/config/client" "@{AllowUnencrypted=`"true`"}"
Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0

& cmd /c --% docker-compose -f spec/docker-compose-windev.yml --verbose --no-ansi up -d --build 2>&1
