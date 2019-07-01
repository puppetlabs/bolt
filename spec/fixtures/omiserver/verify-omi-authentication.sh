#!/bin/sh
set -e

if [ -z ${BOLT_PASSWORD} ]; then
    echo "No BOLT_PASSWORD Provided. Exiting ..."
    exit 1
fi

cat << EOF

************************************************************
Verifying HTTPS Basic auth bolt:${BOLT_PASSWORD} with omicli
************************************************************

EOF

/opt/omi/bin/omicli --hostname omiserver -u bolt -p ${BOLT_PASSWORD} id --auth Basic --encryption https
