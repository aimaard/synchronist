#!/bin/sh
set -e

bundle exec rails db:prepare

exec bundle exec "$@"
