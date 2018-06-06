#!/usr/bin/env bash

# Delegate to facter if available
command -v facter > /dev/null 2>&1 && exec facter -p --json

minor () {
    minor="${*#*.}"
    [ "$minor" == "$*" ] || echo "${minor%%.*}"
}

# Determine the OS name
if [ -f /etc/redhat-release ]; then
    if egrep -iq centos /etc/redhat-release; then
        name=CentOS
    elif egrep -iq 'Fedora release' /etc/redhat-release; then
        name=Fedora
    fi
    release=$(sed -r -e 's/^.* release ([0-9]+(\.[0-9]+)?).*$/\1/' \
                  /etc/redhat-release)
fi

if [ -z "${name}" ]; then
    LSB_RELEASE=$(command -v lsb_release)
    if [ -n "$LSB_RELEASE" ]; then
        if [ -z "$name" ]; then
            name=$($LSB_RELEASE -i | sed -re 's/^.*:[ \t]*//')
        fi
        release=$($LSB_RELEASE -r | sed -re 's/^.*:[ \t]*//')
    fi
fi

# if lsb not available try os-release
if [ -z "${name}" ]; then
    if [ -e /etc/os-release ]; then
        name=$(grep "^NAME" /etc/os-release | cut -d'=' -f2 | sed "s/\"//g")
        release=$(grep "^VERSION_ID" /etc/os-release | cut -d'=' -f2 | sed "s/\"//g")
    elif [-e /usr/lib/os-release ]; then
        name=$(grep "^NAME" /usr/lib/os-release | cut -d'=' -f2 | sed "s/\"//g")
        release=$(grep "^VERSION_ID" /usr/lib/os-release | cut -d'=' -f2 | sed "s/\"//g")
    fi
    if [ -n "${name}" ]; then
        if echo "${name}" | egrep -iq "(.*red)(.*hat)"; then
            name="RedHat"
        elif echo "${name}" | egrep -iq "debian"; then
            name="Debian"
        fi
    fi
fi

if [ -z "${name}" ]; then
    name=$(uname)
    release=$(uname -r)
fi

case $name in
    RedHat|Fedora|CentOS|Scientific|SLC|Ascendos|CloudLinux)
        family=RedHat;;
    HuaweiOS|LinuxMint|Ubuntu|Debian)
        family=Debian;;
    *)
        family=$name;;
esac

# Print it all out
if [ -z "$name" ]; then
    cat <<JSON
{
  "_error": {
    "kind": "facts/noname",
    "msg": "Could not determine OS name"
  }
}
JSON
else
    cat <<JSON
{
  "os": {
    "name": "${name}",
JSON
    [ -n "$release" ] && cat <<JSON
    "release": {
      "full": "${release}",
      "major": "${release%%.*}",
      "minor": "`minor "${release}"`"
    },
JSON
    cat <<JSON
    "family": "${family}"
  }
}
JSON
fi
