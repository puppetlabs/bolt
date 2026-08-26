FROM rastasheep/ubuntu-sshd:18.04

ARG PUPPET_COLLECTION

# Install required packages
RUN apt-get update
RUN apt-get -y install apt-transport-https locales sudo tree wget

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Install the puppet-agent package
# sudo is important here so puppet is added to the path
RUN if [ -n "$PUPPET_COLLECTION" ]; then \
    wget -q https://apt.puppetlabs.com/${PUPPET_COLLECTION}-release-bionic.deb \
    && sudo dpkg -i ${PUPPET_COLLECTION}-release-bionic.deb \
    && sudo apt-get update \
    && sudo apt-get -y install puppet-agent ; \
    fi

# Add 'bolt' user
RUN useradd bolt
RUN echo "bolt:bolt" | chpasswd
RUN adduser bolt sudo

RUN mkdir -p /home/bolt/.ssh
COPY fixtures/keys/id_rsa.pub /home/bolt/.ssh/id_rsa.pub
COPY fixtures/keys/id_ed25519.pub /home/bolt/.ssh/id_ed25519.pub
RUN cat /home/bolt/.ssh/*.pub > /home/bolt/.ssh/authorized_keys
RUN chmod 700 /home/bolt/.ssh
RUN chmod 600 /home/bolt/.ssh/authorized_keys
RUN chown -R bolt:sudo /home/bolt

# Add 'test' user with different login shell
RUN useradd test
RUN echo "test:test" | chpasswd
RUN adduser test sudo
RUN echo test | chsh -s /bin/bash test

RUN mkdir -p /home/test/.ssh
COPY fixtures/keys/id_rsa.pub /home/test/.ssh/id_rsa.pub
COPY fixtures/keys/id_ed25519.pub /home/test/.ssh/id_ed25519.pub
RUN cat /home/test/.ssh/*.pub > /home/test/.ssh/authorized_keys
RUN chmod 700 /home/test/.ssh
RUN chmod 600 /home/test/.ssh/authorized_keys
RUN chown -R test:sudo /home/test

# Run the sshd service in the background
CMD [ "/usr/sbin/sshd", "-D" ]
