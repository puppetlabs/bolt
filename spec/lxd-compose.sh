#!/bin/bash

set -o history -o histexpand -o nounset -e

# remove container if existing
lxc delete ubuntunode --force || true

# create and start ubuntu container
lxc launch ubuntu:bionic ubuntunode

# configure and start ssh so we can ssh into it with user root and password root
lxc exec ubuntunode -- ssh-keygen -A
lxc exec ubuntunode -- sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
lxc exec ubuntunode -- sed -i -e 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
lxc exec ubuntunode -- bash -c 'echo -e "root\nroot" | passwd root'
lxc exec ubuntunode -- service ssh start

# add port forwarding for localhost only
lxc config device add ubuntunode ext-ssh proxy listen=tcp:127.0.0.1:20032 connect=tcp:127.0.0.1:22
