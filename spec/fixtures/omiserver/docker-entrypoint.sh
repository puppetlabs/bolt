#!/bin/bash

/opt/omi/bin/omiserver --version
pwsh --version

/opt/omi/bin/omiserver -d
echo 'Daemonized OMI server'
tail -f /var/opt/omi/log/omiserver.log
