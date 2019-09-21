FROM puppet/puppetdb

ARG hostname="bolt-puppetdb"

# Use our own certs so this doesn't have to wait for puppetserver startup
COPY fixtures/ssl/ca.pem /etc/puppetlabs/puppet/ssl/certs/ca.pem
COPY fixtures/ssl/cert.pem /etc/puppetlabs/puppet/ssl/certs/pdb.pem
COPY fixtures/ssl/key.pem /etc/puppetlabs/puppet/ssl/private_keys/pdb.pem
COPY fixtures/ssl/crl.pem /etc/puppetlabs/puppet/ssl/ca/ca_crl.pem

# Use our own entrypoint
COPY fixtures/puppetdb/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
