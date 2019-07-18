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
Verifying HTTPS Basic auth bolt:${BOLT_PASSWORD} with omicli
************************************************************

EOF

/opt/omi/bin/omicli --hostname omiserver -u bolt -p ${BOLT_PASSWORD} id --auth Basic --encryption https

cat << EOF

************************************************************
Verifying HTTP SPNEGO auth bolt:${BOLT_PASSWORD} with omicli
************************************************************

EOF

/opt/omi/bin/omicli --hostname omiserver -u bolt -p ${BOLT_PASSWORD} id --auth NegoWithCreds --encryption http


cat << EOF

************************************************************
Verifying HTTPS SPNEGO auth bolt:${BOLT_PASSWORD} with omicli
************************************************************

EOF

/opt/omi/bin/omicli --hostname omiserver -u bolt -p ${BOLT_PASSWORD} id --auth NegoWithCreds --encryption https

# oddly, password must be supplied here to verify the creds??
cat << EOF

************************************************************
Verifying HTTP Kerberos auth Administrator@${KRB5_REALM} ${SMB_ADMIN_PASSWORD} with omicli
************************************************************

EOF

/opt/omi/bin/omicli --hostname omiserver --auth Kerberos -u Administrator@${KRB5_REALM} -p "${SMB_ADMIN_PASSWORD}" id --encryption http

cat << EOF

************************************************************
Verifying HTTPS Kerberos auth Administrator@${KRB5_REALM} ${SMB_ADMIN_PASSWORD} with omicli
************************************************************

EOF

/opt/omi/bin/omicli --hostname omiserver --auth Kerberos -u Administrator@${KRB5_REALM} -p "${SMB_ADMIN_PASSWORD}" id --encryption https
