FROM ubuntu:bionic

COPY scripts/setup.sh /tmp/setup.sh
COPY certs /tmp/certs
RUN /tmp/setup.sh

CMD ["/bolt-service"]
