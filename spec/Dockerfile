# Travis not using 18.04 yet
FROM rastasheep/ubuntu-sshd:16.04
RUN apt-get update && apt-get -y install sudo tree && apt-get -y install locales
RUN locale-gen en_US.UTF-8

ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8"

# Add bolt user with authorized key
RUN useradd bolt && echo "bolt:bolt" | chpasswd && adduser bolt sudo
RUN mkdir -p /home/bolt/.ssh/
COPY fixtures/keys/id_rsa.pub /home/bolt/.ssh/id_rsa.pub
COPY fixtures/keys/id_rsa.pub /home/bolt/.ssh/authorized_keys
RUN chmod 700 /home/bolt/.ssh/
RUN chmod 600 /home/bolt/.ssh/authorized_keys
RUN chown -R bolt:sudo /home/bolt

# Add test user without authorized key and different login shell
RUN useradd test && echo "test:test" | chpasswd && adduser test sudo
RUN echo test | chsh -s /bin/bash test
RUN mkdir -p /home/test/
RUN chown -R test:sudo /home/test

CMD ["/usr/sbin/sshd", "-D"]
