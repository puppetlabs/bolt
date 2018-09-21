#!/bin/bash

BOLT_SERVER_PACKAGE=pe-bolt-server_0.22.0.7.g3257f59-1bionic_amd64.deb

# Install Puppet-Agent and Bolt Server
apt update -y
apt install -y curl
mkdir /tmp/bolt && pushd /tmp/bolt
# Setup Puppet Agent Repo
curl -O http://nightlies.puppet.com/apt/puppet6-nightly-release-bionic.deb && apt install -y ./puppet6-nightly-release-bionic.deb && rm ./puppet6-nightly-release-bionic.deb && apt update -y

# Install PE Package
apt install -y pe-bolt-server
popd
rm -rf /tmp/bolt

# Create SSL Directory
mkdir -p /etc/puppetlabs/bolt-server/ssl
cd /etc/puppetlabs/bolt-server/ssl
cp /tmp/certs/localhost.crt /tmp/certs/localhost.key /tmp/certs/bolt-server-ca.crt /etc/puppetlabs/bolt-server/ssl/

# Create SSL Config for Bolt Service
cat <<EOF > /etc/puppetlabs/bolt-server/conf.d/bolt-server.conf
bolt-server: {
  ssl-cert: "/etc/puppetlabs/bolt-server/ssl/localhost.crt"
  ssl-key: "/etc/puppetlabs/bolt-server/ssl/localhost.key"
  ssl-ca-cert: "/etc/puppetlabs/bolt-server/ssl/bolt-server-ca.crt"
  port: 62658
  host: 0.0.0.0
}
EOF

# Set Permissions
chown -R pe-bolt-server:pe-bolt-server /etc/puppetlabs/bolt-server/*

# Create service script for docker CMD
cat <<EOF > /bolt-service
#!/bin/sh
GEM_PATH=/opt/puppetlabs/server/apps/bolt-server/lib/ruby:/opt/puppetlabs/puppet/lib/ruby/gems/2.5.0:/opt/puppetlabs/puppet/lib/ruby/vendor_gems /opt/puppetlabs/server/apps/bolt-server/bin/bolt-server -C /opt/puppetlabs/server/apps/bolt-server/puma_config.rb -e production
EOF
chmod u+x /bolt-service
