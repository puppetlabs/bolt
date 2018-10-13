FROM ruby:2.5.1
RUN apt-get update -qq && apt-get install -y ruby-dev

RUN mkdir /bolt-server
WORKDIR /bolt-server
ADD . /bolt-server
RUN bundle install

EXPOSE 62658
ENV BOLT_SERVER_CONF /bolt-server/config/docker.conf

ENTRYPOINT bundle exec puma -C puma_config.rb
