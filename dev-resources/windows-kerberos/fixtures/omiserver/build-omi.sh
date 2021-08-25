#!/bin/sh
# inspired by https://github.com/microsoft/omi/blob/master/docker/nightly/ubuntu16.04/Dockerfile
set -e

ORIGINAL_PATH=`pwd`

cat << EOF

************************************************************
Building OMI server from source...
************************************************************

EOF

export OMI_VERSION=$(git -C /tmp/omi describe --tags | cut -d - -f 1 | sed 's/^v//')

cat << EOF

************************************************************
Detected OMI candidate version from git tag: ${OMI_VERSION}
************************************************************

EOF

export OMI_BUILDVERSION_MAJOR=$(echo $OMI_VERSION | cut -d . -f 1)
export OMI_BUILDVERSION_MINOR=$(echo $OMI_VERSION | cut -d . -f 2)
export OMI_BUILDVERSION_PATCH=$(echo $OMI_VERSION | cut -d . -f 3)
export OMI_BUILDVERSION_BUILDNR=0

cd /tmp/omi/Unix
# this config switch installs to /opt/omi instead of /opt/omi-version
# and makes sure config is loaded from /etc/opt/omi, just like packages
./configure --enable-microsoft --enable-debug
make -j

cat << EOF

************************************************************
Overwrite existing /opt/omi with newly built binaries
************************************************************

EOF

make install
cd $ORIGINAL_PATH

cat << EOF

************************************************************
Enabling VERBOSE logging and restarting omi service
************************************************************

EOF

cat /etc/opt/omi/conf/omiserver.conf \
 | /opt/omi/bin/omiconfigeditor loglevel --set 'VERBOSE' \
 | /opt/omi/bin/omiconfigeditor loglevel --uncomment \
 >/tmp/tmp.conf \
 && mv -f /tmp/tmp.conf /etc/opt/omi/conf/omiserver.conf

service omid restart
