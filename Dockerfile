FROM rastasheep/ubuntu-sshd

RUN locale-gen en_US.UTF-8

ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8"

RUN apt-get update && apt-get -y install sudo tree

# Add bolt user
RUN useradd bolt && echo "bolt:bolt" | chpasswd && adduser bolt sudo

# Add SSH key support
RUN mkdir -p /home/bolt/.ssh/
COPY spec/fixtures/keys/id_rsa.pub /home/bolt/.ssh/id_rsa.pub
COPY spec/fixtures/keys/id_rsa.pub /home/bolt/.ssh/authorized_keys
RUN chown -R bolt:sudo /home/bolt

CMD ["/usr/sbin/sshd", "-D"]