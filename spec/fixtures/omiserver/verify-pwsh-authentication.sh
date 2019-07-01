#!/bin/sh
set -e

if [ -z ${BOLT_PASSWORD} ]; then
    echo "No BOLT_PASSWORD Provided. Exiting ..."
    exit 1
fi

cat << EOF

************************************************************
Verifying HTTPS Basic auth bolt:${BOLT_PASSWORD} with pwsh
************************************************************

EOF

COMMAND='-Command { $PSVersionTable }'
AUTH='-Authentication Basic'
SSL='-UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)'
PASS='(ConvertTo-SecureString $ENV:BOLT_PASSWORD -AsPlainText -Force)'
CREDS="-Credential (New-Object System.Management.Automation.PSCredential('bolt', $PASS))"
PS="Invoke-Command -ComputerName omiserver $COMMAND $AUTH $SSL $CREDS"
/usr/bin/pwsh -Command ''$PS'' | tee /tmp/psversion.txt

cat /tmp/psversion.txt | grep ^OS.*Linux
