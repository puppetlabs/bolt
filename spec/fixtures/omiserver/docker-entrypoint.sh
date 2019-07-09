#!/bin/bash
set -e

/opt/omi/bin/omiserver --version
pwsh --version

./kerberos-client-config.sh
./domain-join.sh

cat << EOF

************************************************************
Daemonizing OMI server
************************************************************

EOF

/opt/omi/bin/omiserver -d
# there is a race here which may cause the log to not be created yet
sync

./omi-enable-kerberos-auth.sh
./verify-omi-authentication.sh
./verify-pwsh-authentication.sh

cat << EOF

************************************************************
Tailing OMI Server Logs - Extra Logs: ${OMI_EXTRA_LOGS}
************************************************************

EOF

if [ "$OMI_EXTRA_LOGS" = "true" ]
then
  tail -f /var/opt/omi/log/omiserver.log \
    /var/log/sssd/sssd.log \
    /var/opt/omi/log/omiserver-recv.trc \
    /var/opt/omi/log/omiserver-send.trc
else
  tail -f /var/opt/omi/log/omiserver.log
fi
