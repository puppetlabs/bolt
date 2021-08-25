#!/bin/sh
set -e

cat << EOF

************************************************************
Configuring Krb5 Client
************************************************************

EOF

if [ -z ${KRB5_REALM} ]; then
    echo "No KRB5_REALM Provided. Exiting ..."
    exit 1
fi

if [ -z ${KRB5_KDC} ]; then
    echo "No KRB5_KDC Provided. Exiting ..."
    exit 1
fi

if [ -z ${KRB5_ADMINSERVER} ]; then
    echo "KRB5_ADMINSERVER not provided. Using KRB5_KDC value ${KRB5_KDC}"
    export KRB5_ADMINSERVER=${KRB5_KDC}
fi

if [ -z ${KRB5_CONFIG} ]; then
    echo "KRB5_CONFIG not provided. Using /etc/krb5.conf"
    export KRB5_CONFIG=/etc/krb5.conf
fi

cat << EOF

************************************************************
Creating Krb5 Client Configuration ${KRB5_CONFIG}
************************************************************

EOF

export KRB5_REALM_LOWER=$(echo "${KRB5_REALM}" | tr '[:upper:]' '[:lower:]')
TEMPLATE_PATH=$(dirname "$(readlink -f "$0")")
envsubst < ${TEMPLATE_PATH}/krb5.conf.tmpl | tee ${KRB5_CONFIG}
