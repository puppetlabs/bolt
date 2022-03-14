#!/bin/bash

mkdir -p ~/.puppetlabs/etc/bolt
rm -f ~/.puppetlabs/etc/bolt/bolt-defaults.yaml

cd ~/bolt

cat << EOF

************************************************************
Using Bolt to retrieve username using:

Basic auth bolt:${BOLT_PASSWORD}
************************************************************

EOF

bundle exec bolt command run "whoami" --targets winrm://omiserver.bolt.test:5985 --user bolt --password $BOLT_PASSWORD --no-ssl
bundle exec bolt command run "whoami" --targets winrm://omiserver.bolt.test:5986 --user bolt --password $BOLT_PASSWORD --no-ssl-verify

cat << EOF

************************************************************
Using PowerShell to retrieve username using:

HTTP Kerberos auth ${SMB_ADMIN}@${KRB5_REALM} ${SMB_ADMIN_PASSWORD}

NOTE: Expected error will result when closing connection

[omiserver] Closing the remote server shell instance failed with the following error message : ERROR_INTERNAL_ERROR
************************************************************

EOF

/usr/bin/pwsh -Command 'Invoke-Command -ComputerName omiserver -Command { whoami } -Authentication Kerberos -Credential (New-Object System.Management.Automation.PSCredential("${ENV:SMB_ADMIN}@${ENV:KRB5_REALM}", (ConvertTo-SecureString $ENV:SMB_ADMIN_PASSWORD -AsPlainText -Force)))'
# set default kerb realm for testing this way


cat << EOF>~/.puppetlabs/etc/bolt/bolt-defaults.yaml
---
inventory-config:
  winrm:
    realm: BOLT.TEST
EOF

cat << EOF

************************************************************
Using Bolt to retrieve username using:

HTTP Kerberos auth ${SMB_ADMIN}@${KRB5_REALM} ${SMB_ADMIN_PASSWORD}

NOTE: Expected error will result when transferring data due to a Kerberos
negotiation bug between winrm gem and omi server:

Failed on omiserver.bolt.test:
  Failed to connect to http://omiserver.bolt.test:5985/wsman:
  Unable to parse WinRM response: #<ArgumentError: invalid byte sequence in UTF-8>

<Encoding::UndefinedConversionError> "\xXX" from ASCII-8BIT to UTF-8
************************************************************

EOF

bundle exec bolt command run "whoami" --targets winrm://omiserver.bolt.test:5985 --no-ssl --debug --verbose --connect-timeout 9999

cat << EOF

************************************************************
Using Bolt to retrieve username using:

HTTPS Kerberos auth ${SMB_ADMIN}@${KRB5_REALM} ${SMB_ADMIN_PASSWORD}

NOTE: Expected error will result when transferring data due to a Kerberos
negotiation bug between winrm gem and omi server:

Failed on omiserver.bolt.test:
  Failed to connect to https://omiserver.bolt.test:5986/wsman:
  Bad HTTP response returned from server. Body(if present)

<Encoding::UndefinedConversionError> "\xXX" from ASCII-8BIT to UTF-8
************************************************************

EOF

bundle exec bolt command run "whoami" --targets winrm://omiserver.bolt.test:5986 --no-ssl-verify --debug --verbose --connect-timeout 9999
