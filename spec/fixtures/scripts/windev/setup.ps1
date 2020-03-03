$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

$User = 'bolt'
$Password = 'bolt'

# Disable password complexity requirements
secedit /export /cfg c:\secpol.cfg
(gc C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
rm -force c:\secpol.cfg -confirm:$false

# add the bolt user account
New-LocalUser -Name $User -Password (ConvertTo-SecureString -String $Password -Force -AsPlainText)
#Add-LocalGroupMember -Group 'Remote Management Users' -Member $User
Add-LocalGroupMember -Group 'Administrators' -Member $User

# Enable WinRM
Enable-PSRemoting
winrm "set" "winrm/config/service/auth" "@{Kerberos=`"false`"}"
winrm "set" "winrm/config/service" "@{AllowUnencrypted=`"true`"}"
