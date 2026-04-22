#!/usr/bin/env bash
set -euo pipefail

source /opt/ood/ondemand/enable

dashboard_dir="/var/www/ood/apps/sys/dashboard"

cd "$dashboard_dir"

SECRET_KEY_BASE="${SECRET_KEY_BASE:-asset-build-only}"
RAILS_ENV=production
RAILS_RELATIVE_URL_ROOT=/pun/sys/dashboard

export SECRET_KEY_BASE
export RAILS_ENV
export RAILS_RELATIVE_URL_ROOT

/opt/ood/gems/bin/bundle exec bin/rails assets:clobber assets:precompile

touch tmp/restart.txt
