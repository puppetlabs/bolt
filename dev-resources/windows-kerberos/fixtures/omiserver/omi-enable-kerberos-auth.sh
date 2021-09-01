#!/bin/sh
set -e

if [ -z ${SMB_ADMIN} ]; then
    echo "No SMB_ADMIN Provided. Exiting ..."
    exit 1
fi

if [ -z ${SMB_ADMIN_PASSWORD} ]; then
    echo "No SMB_ADMIN_PASSWORD Provided. Exiting ..."
    exit 1
fi

# it's important to restart the sssd service after updating the keytab
# (originally generated as part of the `realm join`)
cat << EOF

************************************************************
Updating Kerberos keytab file for ${SMB_ADMIN}
************************************************************

EOF

echo "${SMB_ADMIN_PASSWORD}" | net ads keytab add HTTP -U ${SMB_ADMIN}

cp /etc/krb5.keytab /etc/opt/omi/creds/omi.keytab
chown omi:omi /etc/opt/omi/creds/omi.keytab
# dumps the contents of the keyfile
klist -Kke

# WinRM gem requests the HTTP SPN when connecting
# https://github.com/WinRb/WinRM/blob/2a9a2ff55c5bbd903a019d63b1d134ac32ead4c7/lib/winrm/http/transport.rb#L299
cat << EOF

************************************************************
Verifying HTTP SPN in Active Directory (Samba)
************************************************************

EOF

net ads dn --kerberos 'CN=OMISERVER,CN=Computers,DC=bolt,DC=test' servicePrincipalName

net ads dn --kerberos 'CN=OMISERVER,CN=Computers,DC=bolt,DC=test' servicePrincipalName \
  | grep 'HTTP/omiserver.bolt.test'

# NOTE: similar information can be acquired with tools available on the DC:
# samba-tool spn list OMISERVER$
# samba-tool computer list
# samba-tool computer show OMISERVER$
# Adding new SPNs takes the form:
# samba-tool spn add HTTP/OMISERVER@BOLT.TEST OMISERVER$

cat << EOF

************************************************************
Restarting sssd service
************************************************************

EOF

service sssd restart
service sssd status
# dump all the sssd log files
cat /var/log/sssd/*
