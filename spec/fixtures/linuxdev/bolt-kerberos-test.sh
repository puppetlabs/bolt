#!/bin/bash
set -e

mkdir -p ~/.puppetlabs/bolt
rm ~/.puppetlabs/bolt/bolt.yaml

cd ~/bolt

bundle exec bolt command run "whoami" --nodes winrm://omiserver.bolt.test:5985 --user bolt --password bolt --no-ssl
bundle exec bolt command run "whoami" --nodes winrm://omiserver.bolt.test:5986 --user bolt --password bolt --no-ssl-verify


# set default kerb realm for testing this way
cat << EOF>~/.puppetlabs/bolt/bolt.yaml
---
winrm:
  realm: BOLT.TEST
EOF

bundle exec bolt command run "whoami" --nodes winrm://omiserver.bolt.test:5985 --no-ssl --debug --verbose --connect-timeout 9999
bundle exec bolt command run "whoami" --nodes winrm://omiserver.bolt.test:5986 --no-ssl-verify --debug --verbose --connect-timeout 9999

# can do this in pwsh
# Invoke-Command -ComputerName omiserver -Command { whoami } -Authentication Kerberos -Credential (New-Object System.Management.Automation.PSCredential("${ENV:SMB_ADMIN}@${ENV:KRB5_REALM}", (ConvertTo-SecureString $ENV:SMB_ADMIN_PASSWORD -AsPlainText -Force)))
