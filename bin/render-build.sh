#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
npm install
npm run build
bundle exec rails assets:precompile
bundle exec rails db:migrate
