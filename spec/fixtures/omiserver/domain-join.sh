#!/bin/sh
set -e

if [ -z ${KRB5_REALM} ]; then
    echo "No KRB5_REALM Provided. Exiting ..."
    exit 1
fi

if [ -z ${SMB_DOMAIN} ]; then
    echo "No SMB_DOMAIN Provided. Exiting ..."
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

# since we're in Docker, it shouldn't be necessary to sync NTP

cat << EOF

************************************************************
Checking realm DNS
************************************************************

EOF

export KRB5_REALM_LOWER=$(echo "${KRB5_REALM}" | tr '[:upper:]' '[:lower:]')
LDAP_DNS="_ldap._tcp.${KRB5_REALM_LOWER}"
until host -t SRV -v ${LDAP_DNS}
do
    echo "Waiting for ${LDAP_DNS} to resolve... exit status: $?"
    sleep 1s
done
# show that DNS record exists
host -t SRV -v ${LDAP_DNS}

cat << EOF

************************************************************
Initializing Kerberos client
************************************************************

EOF

# wait for the DC to be listening
until echo "${SMB_ADMIN_PASSWORD}" | KRB5_TRACE=/dev/stdout kinit "${SMB_ADMIN}"
do
    echo "Waiting to retrieve ticket granting ticket from domain controller... exit status: $?"
    sleep 1s
done
# show the ticket granting ticket
KRB5_TRACE=/dev/stdout klist

cat << EOF

************************************************************
GNU Name Sevice Switch Configuration
************************************************************

EOF
# this should include `sss` for passwd, group, shadow, services, netgroup, sudoers
cat /etc/nsswitch.conf

cat << EOF

************************************************************
Creating realmd.conf
************************************************************

EOF

envsubst < realmd.conf.tmpl | tee /etc/realmd.conf

cat << EOF

************************************************************
Creating /etc/samba/smb.conf
************************************************************

EOF

cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
envsubst < smb.conf.tmpl | tee /etc/samba/smb.conf

cat << EOF

************************************************************
Creating /etc/samba/user.map
************************************************************

EOF

envsubst < user.map.tmpl | tee /etc/samba/user.map


cat << EOF

************************************************************
Joining domain ${KRB5_REALM_LOWER} as ${SMB_ADMIN} using realm
************************************************************

EOF

# waiting for: realm: Already joined to this domain
until echo "${SMB_ADMIN_PASSWORD}" |
  realm --verbose join "${KRB5_REALM_LOWER}" -U ${SMB_ADMIN} --install=/ 2>&1 |
  tee join.txt |
  grep -q "Already joined to this domain"
do
    # When successful:
    # omiserver_1      | Joining domain bolt.test with realm command
    # omiserver_1      |  * Resolving: _ldap._tcp.bolt.test
    # omiserver_1      |  * Performing LDAP DSE lookup on: 172.22.0.100
    # omiserver_1      |  * Successfully discovered: bolt.test
    # omiserver_1      | realm: Already joined to this domain

    # omiserver_1      | Server time: Tue, 18 Jun 2019 22:47:17 UTC

    # When unsuccesful:
    # omiserver_1      | Joining domain bolt.test with realm command
    # omiserver_1      |  * Resolving: _ldap._tcp.bolt.test
    # omiserver_1      |  * Performing LDAP DSE lookup on: 172.22.0.100
    # omiserver_1      |  ! Can't contact LDAP server
    # omiserver_1      | realm: Cannot join this realm
    # omiserver_1      | Failed to get server's current time!

    # omiserver_1      | Server time: Thu, 01 Jan 1970 00:00:00 UTC

    cat join.txt
    echo "Waiting for successful domain join...\n"
    sleep 1s
done
cat join.txt

cat << EOF

************************************************************
net ads join ${SMB_ADMIN}%${SMB_ADMIN_PASSWORD}
************************************************************

EOF

# https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Domain_Member#Joining_the_Domain
# DO NOT use `samba-tool domain join` per documentation
net ads join --user ${SMB_ADMIN}%${SMB_ADMIN_PASSWORD}

cat << EOF

************************************************************
Creating sssd.conf / setting permissions / ownership
************************************************************

EOF

envsubst < sssd.conf.tmpl | tee /etc/sssd/sssd.conf

# sssd service won't start without perms of 0600 and correct owner
chmod 0600 /etc/sssd/sssd.conf
chown root:root /etc/sssd/sssd.conf
ls -rtaFl /etc/sssd/sssd.conf

cat << EOF

************************************************************
PAM config
************************************************************

EOF

ls -rtaFl /etc/pam.d/common-*
grep -E 'sss|mkhomedir' /etc/pam.d/common-*

cat << EOF

************************************************************
Starting sssd service
************************************************************

EOF

service sssd start

# emit information about domain join
cat << EOF

************************************************************
Verifying realm ${KRB5_REALM_LOWER}
************************************************************

EOF
realm --verbose discover "${KRB5_REALM_LOWER}" --install=/

cat << EOF

************************************************************
net ads info
************************************************************

EOF

net ads info

cat << EOF

************************************************************
Verifying sssd service
************************************************************

EOF

service sssd status
ps aux | grep sssd

cat << EOF

************************************************************
Verifying ${SMB_ADMIN}@${KRB5_REALM} user can be looked up
************************************************************

EOF

getent passwd ${SMB_ADMIN}@${KRB5_REALM}
getent passwd ${SMB_DOMAIN}\\${SMB_ADMIN}
# should produce something like:
# administrator:*:1219600500:1219600513:Administrator:/home/administrator@BOLT.TEST:
# dump all the sssd log files
sync
cat /var/log/sssd/*
