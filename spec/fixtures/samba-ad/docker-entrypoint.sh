#!/bin/sh

./samba-ad-config.sh
./kerberos-client-config.sh

/usr/bin/supervisord -c /etc/supervisord.conf
