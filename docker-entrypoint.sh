#!/bin/sh

bundle exec rails db:prepare
bundle exec rails db:seed

bundle exec "$@"
