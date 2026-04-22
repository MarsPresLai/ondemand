#!/usr/bin/env bash
set -euo pipefail

source /opt/ood/ondemand/enable

myjobs_dir="/var/www/ood/apps/sys/myjobs"

cd "$myjobs_dir"

SECRET_KEY_BASE="${SECRET_KEY_BASE:-asset-build-only}"
RAILS_ENV=production
RAILS_RELATIVE_URL_ROOT=/pun/sys/myjobs

export SECRET_KEY_BASE
export RAILS_ENV
export RAILS_RELATIVE_URL_ROOT

/opt/ood/gems/bin/bundle exec bin/rake assets:clobber assets:precompile

touch tmp/restart.txt
