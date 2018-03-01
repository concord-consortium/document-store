#!/bin/bash

# This script is intended to be run inside of a development Docker container.

DB_CONFIG=$APP_HOME/config/database.yml
PIDFILE=$APP_HOME/tmp/pids/server.pid

if [ -f $PIDFILE ]; then
  rm $PIDFILE
fi

if [ ! -f $DB_CONFIG ]; then
  cp $APP_HOME/config/database.yml.docker $DB_CONFIG
fi

bundle check || bundle install

if [ "$RAILS_ENV" = "production" ]; then
  bundle exec rake assets:precompile
fi

if [ "$1" == "migrate-only" ]; then
  bundle exec rake db:create
  bundle exec rake db:migrate
elif [ "$1" == "rails-only" ]; then
  bundle exec unicorn -p 3001 -c ./config/unicorn.rb
else
  bundle exec rake db:create
  bundle exec rake db:migrate
  bundle exec unicorn -p 3001 -c ./config/unicorn.rb
fi
