#!/bin/bash
set -euo pipefail

AUTH_MODE="${OOD_AUTH_MODE:-local}"
CONFIG_SOURCE="/workspace/ondemand/docker/config"
OOD_TEMPLATE="/workspace/ondemand/docker/config/ood_portal.${AUTH_MODE}.yml"
DEX_TEMPLATE="/workspace/ondemand/docker/config/dex/config.${AUTH_MODE}.yaml"
DEX_CERT_SOURCE="/workspace/ondemand/docker/config/dex/adfs-ntu.crt"

render_template() {
  local source="$1"
  local target="$2"

  cp "$source" "$target"

  render_placeholder "$target" "__OOD_DEX_CLIENT_SECRET__" "OOD_DEX_CLIENT_SECRET"
  render_placeholder "$target" "__OOD_LOCAL_DEX_CLIENT_SECRET__" "OOD_LOCAL_DEX_CLIENT_SECRET"
  render_placeholder "$target" "__OOD_LOCAL_PASSWORD__" "OOD_LOCAL_PASSWORD"
  render_placeholder "$target" "__OOD_LOCAL_PASSWORD_HASH__" "OOD_LOCAL_PASSWORD_HASH"
  render_placeholder "$target" "__OOD_LOCAL_USER_ID__" "OOD_LOCAL_USER_ID"
}

render_placeholder() {
  local target="$1"
  local token="$2"
  local env_name="$3"

  if ! grep -q "$token" "$target"; then
    return
  fi

  local value="${!env_name:-}"
  if [ -z "$value" ]; then
    echo "$env_name must be set when rendering $target" >&2
    exit 1
  fi

  local escaped="${value//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//#/\\#}"
  sed -i "s#${token}#${escaped}#g" "$target"
}

if [ ! -f "$OOD_TEMPLATE" ]; then
  echo "Missing OOD auth template: $OOD_TEMPLATE" >&2
  exit 1
fi

if [ ! -f "$DEX_TEMPLATE" ]; then
  echo "Missing Dex auth template: $DEX_TEMPLATE" >&2
  exit 1
fi

mkdir -p /etc/ood/config

if [ -d "$CONFIG_SOURCE/apps" ]; then
  cp -a "$CONFIG_SOURCE/apps" /etc/ood/config/
fi

if [ -d "$CONFIG_SOURCE/clusters.d" ]; then
  cp -a "$CONFIG_SOURCE/clusters.d" /etc/ood/config/
fi

render_template "$OOD_TEMPLATE" /etc/ood/config/ood_portal.yml

if [ -f "$DEX_CERT_SOURCE" ]; then
  mkdir -p /etc/ood/dex
  cp "$DEX_CERT_SOURCE" /etc/ood/dex/adfs-ntu.crt
  chmod 644 /etc/ood/dex/adfs-ntu.crt
fi

build_dashboard_assets() {
  local dashboard_dir="/var/www/ood/apps/sys/dashboard"

  if [ ! -d "$dashboard_dir" ]; then
    return
  fi

  mkdir -p "$dashboard_dir/app/assets/builds" "$dashboard_dir/tmp"
  mkdir -p "$dashboard_dir/tmp/cache/assets"
  chown -R misaki:misaki "$dashboard_dir/app/assets/builds" "$dashboard_dir/tmp" "$dashboard_dir/node_modules" 2>/dev/null || true
  chmod 1777 "$dashboard_dir/tmp" "$dashboard_dir/tmp/cache" "$dashboard_dir/tmp/cache/assets" 2>/dev/null || true
  chmod 1777 "$dashboard_dir/app/assets/builds" 2>/dev/null || true
  find "$dashboard_dir/tmp/cache/assets" -type d -exec chmod 1777 {} + 2>/dev/null || true
  find "$dashboard_dir/tmp/cache/assets" -type f -exec chmod 666 {} + 2>/dev/null || true

  su -s /bin/bash -c "
    set -euo pipefail
    cd '$dashboard_dir'
    npm install --no-package-lock --no-fund --no-audit >/tmp/dashboard-npm-install.log 2>&1
    npm run build >/tmp/dashboard-npm-build.log 2>&1
    npm run build:css >/tmp/dashboard-npm-css.log 2>&1
  " misaki
}

build_dashboard_assets

/opt/ood/ood-portal-generator/sbin/update_ood_portal

if [ -f /etc/httpd/conf.d/ood-portal.conf.new ]; then
  cp /etc/httpd/conf.d/ood-portal.conf.new /etc/httpd/conf.d/ood-portal.conf
fi

# The container sits behind the host's TLS terminator, so serve plain HTTP on
# the internal port and let Apache talk to the local Dex instance directly.
sed -i 's#<VirtualHost \*:443>#<VirtualHost *:18080>#' /etc/httpd/conf.d/ood-portal.conf
sed -i '/Header always set Strict-Transport-Security/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/SSLEngine On/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/SSLCertificateFile/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/SSLCertificateKeyFile/d' /etc/httpd/conf.d/ood-portal.conf
sed -i 's#^  OIDCProviderMetadataURL .*#  OIDCProviderMetadataURL http://localhost:5556/dex/.well-known/openid-configuration#' /etc/httpd/conf.d/ood-portal.conf

# Keep the custom public landing page as the first page, matching the live site.
sed -i '/RedirectMatch \^\/\$ "\/pun\/sys\/dashboard"/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/RewriteRule \^\/\$ \/public\/index.html \[PT,L\]/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/RewriteRule \^(.\*) http:\/\/localhost:18080\$1 \[R=301,NE,L\]/a\  RewriteRule ^/$ /public/index.html [PT,L]' /etc/httpd/conf.d/ood-portal.conf

if [ -f "$DEX_TEMPLATE" ]; then
  mkdir -p /etc/ood/dex
  render_template "$DEX_TEMPLATE" /etc/ood/dex/config.yaml
  chown ondemand-dex:ondemand-dex /etc/ood/dex/config.yaml
  chmod 600 /etc/ood/dex/config.yaml
fi

mkdir -p /run/httpd

/usr/sbin/ondemand-dex serve /etc/ood/dex/config.yaml >/var/log/ondemand-dex.log 2>&1 &

exec /usr/sbin/httpd -DFOREGROUND
