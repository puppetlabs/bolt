# Install gems
FROM alpine:3.8 as build

RUN \
apk --no-cache add build-base ruby-dev ruby-bundler ruby-json ruby-bigdecimal git openssl-dev && \
echo 'gem: --no-document' > /etc/gemrc && \
bundle config --global silence_root_warning 1

RUN mkdir /bolt-server
# Gemfile requires gemspec which requires bolt/version which requires bolt
ADD . /bolt-server
WORKDIR /bolt-server
RUN bundle install --no-cache --path vendor/bundle

# Final image
FROM alpine:3.8
ARG bolt_version=no-version
LABEL org.label-schema.maintainer="Puppet Bolt Team <team-direct-change-bolt@puppet.com>" \
      org.label-schema.vendor="Puppet" \
      org.label-schema.url="https://github.com/puppetlabs/bolt" \
      org.label-schema.name="PE Bolt Server" \
      org.label-schema.license="Apache-2.0" \
      org.label-schema.version=${bolt_version} \
      org.label-schema.vcs-url="https://github.com/puppetlabs/bolt" \
      # Same with these
      #org.label-schema.vcs-ref="b75674e1fbf52f7821f7900ab22a19f1a10cafdb" \
      #org.label-schema.build-date="2018-05-09T20:10:01Z" \
      #org.label-schema.schema-version="1.0" \
      org.label-schema.dockerfile="/Dockerfile"

RUN \
apk --no-cache add ruby openssl ruby-bundler ruby-json ruby-bigdecimal

COPY --from=build /bolt-server /bolt-server
WORKDIR /bolt-server

EXPOSE 62658
ENV BOLT_SERVER_CONF /bolt-server/config/docker.conf

ENTRYPOINT bundle exec puma -C puma_config.rb
