#!/bin/bash
set -e

pwsh --version

./kerberos-client-config.sh
./domain-join.sh

sync

./verify-pwsh-authentication.sh

cat << EOF

************************************************************
Tailing SSH logs
************************************************************

EOF

touch /var/log/ssh.log
tail -f /var/log/ssh.log
