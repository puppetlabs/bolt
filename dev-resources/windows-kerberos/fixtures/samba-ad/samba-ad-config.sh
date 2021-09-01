#!/bin/sh
set -e

cat << EOF

************************************************************
Configuring Samba
************************************************************

EOF

if [ -z ${KRB5_REALM} ]; then
    echo "No KRB5_REALM Provided. Exiting ..."
    exit 1
fi

if [ -z ${SMB_DOMAIN} ]; then
    echo "No SMB_DOMAIN Provided. Exiting ..."
    exit 1
fi

if [ -z ${SMB_ADMIN_PASSWORD} ]; then
    echo "No SMB_ADMIN_PASSWORD Provided. Exiting ..."
    exit 1
fi

cat << EOF

************************************************************
Tool Versions
************************************************************

EOF

echo "samba-tool version: $(samba-tool --version)"
echo "net ads version: $(net ads --version)"

cat << EOF

************************************************************
Provisioning Domain
************************************************************

EOF

echo "Creating Samba SMB Configuration"

export KRB5_REALM_LOWER=$(echo "${KRB5_REALM}" | tr '[:upper:]' '[:lower:]')
envsubst < smb.conf.tmpl | tee /etc/samba/smb.conf

# https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Parameter_Explanation
# https://www.samba.org/samba/docs/current/man-html/samba-tool.8.html
samba-tool domain provision \
    --use-rfc2307 \
    --realm=${KRB5_REALM} \
    --domain=${SMB_DOMAIN} \
    --server-role=dc \
    --adminpass=${SMB_ADMIN_PASSWORD} \
    --dns-backend=SAMBA_INTERNAL

  # DNS forwarder IP address (write 'none' to disable forwarding) [127.0.0.11]:
  # --host-name=HOSTNAME  set hostname
  # --host-ip=IPADDRESS   set IPv4 ipaddress
  # --host-ip6=IP6ADDRESS
  #                       set IPv6 ipaddress
  # --site=SITENAME       set site name
  # --krbtgtpass=PASSWORD
  #                       choose krbtgt password (otherwise random)
  # --machinepass=PASSWORD
  #                       choose machine password (otherwise random)
  # --dnspass=PASSWORD    choose dns password (otherwise random)
  # --ldapadminpass=PASSWORD
  #                       choose password to set between Samba and its LDAP
  #                       backend (otherwise random)
  # Samba Common Options:
  #   -s FILE, --configfile=FILE
  #                       Configuration file
  #   -d DEBUGLEVEL, --debuglevel=DEBUGLEVEL
  #                       debug level
  #   --option=OPTION     set smb.conf option from command line

cat << EOF

************************************************************
Confirming Samba Kerberos library (Heimdal vs MIT)
************************************************************

EOF

smbd -b | grep HEIMDAL
smbd -b | grep HAVE_LIBKADM5SRV_MIT
