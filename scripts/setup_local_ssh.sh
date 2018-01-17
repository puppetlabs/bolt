#!/usr/bin/env bash
set -x
set -e

# Set up password based ssh
sudo adduser --disabled-password --home /home/$BOLT_SSH_USER --gecos "" $BOLT_SSH_USER
echo $BOLT_SSH_USER:$BOLT_SSH_PASSWORD | sudo chpasswd
echo "$BOLT_SSH_USER ALL=(ALL) PASSWD: ALL" | sudo tee /etc/sudoers.d/bolt

# Set up key based ssh
sudo mkdir /home/$BOLT_SSH_USER/.ssh
sudo cp $BOLT_SSH_KEY.pub /home/$BOLT_SSH_USER/.ssh/authorized_keys
sudo chown $BOLT_SSH_USER /home/$BOLT_SSH_USER/.ssh/authorized_keys
sudo chmod 644 /home/$BOLT_SSH_USER/.ssh/authorized_keys
chmod 600 $BOLT_SSH_KEY
ssh -v -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i $BOLT_SSH_KEY $BOLT_SSH_USER@$BOLT_SSH_HOST 'echo hello'
