FROM ruby:4.0.9-alpine3.23 AS rb
RUN apk update && apk add --no-cache build-base libffi-dev nodejs rsync tzdata yarn yaml-dev
COPY Gemfile* package.json yarn.lock ./
RUN yarn install
RUN gem update --system && gem install bundler
RUN bundle config frozen true \
    && bundle config jobs 4 \
    && bundle config deployment true \
    && bundle config without 'development test' \
    && bundle install
ENV RAILS_ENV=production \
    SECRET_KEY_BASE=buildingassets
ADD . .
RUN bundle exec rails assets:clobber && bundle exec rails assets:precompile


FROM ruby:4.0.9-alpine3.23

RUN apk update && apk add --no-cache coreutils rsync tzdata

WORKDIR /synchronist

RUN gem update --system && gem install bundler

RUN bundle config frozen true \
    && bundle config jobs 4 \
    && bundle config deployment true \
    && bundle config without 'development test'

ADD . .

COPY --from=rb vendor/bundle vendor/bundle
COPY --from=rb public/assets public/assets
COPY docker-entrypoint.sh /bin/

ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true \
    SOLID_QUEUE_IN_PUMA=true

# Default locations of the folders, mount them as volumes (see README.md)
ENV SYNCHRONIST_PAYLOAD_PATH=/data/payload/payload.synchronist \
    SYNCHRONIST_SOURCE_FOLDER=/data/source \
    SYNCHRONIST_SEND_FOLDER=/data/send \
    SYNCHRONIST_STORAGE_FOLDER=/data/storage \
    SYNCHRONIST_RECEIVE_FOLDER=/data/receive

# All SQLite databases (app, queue, cable), attachments and the generated secret key base live here
VOLUME /synchronist/storage

ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD wget -q -O /dev/null "http://127.0.0.1:${PORT:-3000}/up" || exit 1
CMD ["rails", "server", "--binding", "0.0.0.0"]
