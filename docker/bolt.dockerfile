FROM alpine:3.5

MAINTAINER Gareth Rushgrove "gareth@puppet.com"

LABEL org.label-schema.vendor="Puppet" \
      org.label-schema.url="https://github.com/puppetlabs/bolt" \
      org.label-schema.name="Bolt" \
      org.label-schema.license="Apache-2.0" \
      org.label-schema.schema-version="1.0" \
      com.puppet.dockerfile="/Dockerfile"

RUN apk add --update --no-cache \
      build-base \
      libffi-dev \
      ca-certificates \
      ruby \
      ruby-io-console \
      ruby-irb \
      ruby-rdoc \
      ruby-dev \
      git && \
      gem install bundler

RUN addgroup -S bolt && adduser -S -g bolt bolt

# As of https://github.com/moby/moby/pull/34263 Docker supports
# setting ownership on Copy, but it's only available since the
# 17.09 edge release of Moby. We'll wait until it's in the
# main release
# COPY --chown=bolt:bolt . /usr/src/bolt
COPY . /usr/src/bolt
RUN chown bolt:bolt /usr/src/bolt
WORKDIR /usr/src/bolt

USER bolt

RUN bundle install --path .bundle

ENTRYPOINT ["bundle", "exec", "bolt"]
CMD ["--help" ]

COPY docker/bolt.dockerfile /Dockerfile
