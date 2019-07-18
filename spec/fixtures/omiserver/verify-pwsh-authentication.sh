#!/bin/sh
set -e

if [ -z ${BOLT_PASSWORD} ]; then
    echo "No BOLT_PASSWORD Provided. Exiting ..."
    exit 1
fi

if [ -z ${KRB5_REALM} ]; then
    echo "No KRB5_REALM Provided. Exiting ..."
    exit 1
fi

if [ -z ${SMB_ADMIN} ]; then
    echo "No SMB_ADMIN Provided. Exiting ..."
    exit 1
fi

if [ -z ${SMB_ADMIN_PASSWORD} ]; then
    echo "No SMB_ADMIN_PASSWORD Provided. Exiting ..."
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

cat << EOF

************************************************************
Verifying HTTP SPNEGO auth bolt:${BOLT_PASSWORD} with pwsh
************************************************************

EOF

AUTH='-Authentication Negotiate'
PS="Invoke-Command -ComputerName omiserver $COMMAND $AUTH $CREDS"
/usr/bin/pwsh -Command ''$PS'' | tee /tmp/psversion.txt

cat /tmp/psversion.txt | grep ^OS.*Linux

cat << EOF

************************************************************
Verifying HTTPS SPNEGO auth bolt:${BOLT_PASSWORD} with pwsh
************************************************************

EOF

AUTH='-Authentication Negotiate'
PS="Invoke-Command -ComputerName omiserver $COMMAND $AUTH $SSL $CREDS"
/usr/bin/pwsh -Command ''$PS'' | tee /tmp/psversion.txt

cat /tmp/psversion.txt | grep ^OS.*Linux

cat << EOF

************************************************************
Verifying HTTP Kerberos auth Administrator@${KRB5_REALM} ${SMB_ADMIN_PASSWORD} with pwsh
************************************************************

EOF

AUTH='-Authentication Kerberos'
KRB_PASS='(ConvertTo-SecureString $ENV:SMB_ADMIN_PASSWORD -AsPlainText -Force)'
KRB_CREDS="-Credential (New-Object System.Management.Automation.PSCredential(\"\${ENV:SMB_ADMIN}@\${ENV:KRB5_REALM}\", $KRB_PASS))"
PS="Invoke-Command -ComputerName omiserver $COMMAND $AUTH $KRB_CREDS"
/usr/bin/pwsh -Command ''$PS'' | tee /tmp/psversion.txt

cat /tmp/psversion.txt | grep ^OS.*Linux

cat << EOF

************************************************************
Verifying HTTPS Kerberos auth Administrator@${KRB5_REALM} ${SMB_ADMIN_PASSWORD} with pwsh
************************************************************

EOF

AUTH='-Authentication Kerberos'
PS="Invoke-Command -ComputerName omiserver $COMMAND $AUTH $SSL $KRB_CREDS"
/usr/bin/pwsh -Command ''$PS'' | tee /tmp/psversion.txt

cat /tmp/psversion.txt | grep ^OS.*Linux
