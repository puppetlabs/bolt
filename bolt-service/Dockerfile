FROM ubuntu:bionic

# Install pe-bolt-server
RUN apt update -y && apt install -y curl
WORKDIR /tmp/bolt
RUN curl -O http://nightlies.puppet.com/apt/puppet6-nightly-release-bionic.deb && apt install -y ./puppet6-nightly-release-bionic.deb && rm ./puppet6-nightly-release-bionic.deb && apt update -y
RUN apt install -y pe-bolt-server

# Create SSL Directory
RUN mkdir -p /etc/puppetlabs/bolt-server/ssl
RUN cp /tmp/certs/* /etc/puppetlabs/bolt-server/ssl/

# Copy config
COPY resources/bolt-server.conf /etc/puppetlabs/bolt-server/conf.d/bolt-server.conf

# All bolt server files must be owned by the pe-bolt-server user
chown -R pe-bolt-server:pe-boltserver /etc/puppetlabs/bolt-server/*

# Copy script to run bolt-service
COPY resources/bolt-service-file /tmp/bolt-service
RUN chmod u+x /tmp/bolt-service

CMD ["/bolt-service"]
