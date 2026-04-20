#!/bin/bash
set -euo pipefail

AUTH_MODE="${OOD_AUTH_MODE:-local}"
CONFIG_SOURCE="/workspace/ondemand/docker/config"
OOD_TEMPLATE="/workspace/ondemand/docker/config/ood_portal.${AUTH_MODE}.yml"
DEX_TEMPLATE="/workspace/ondemand/docker/config/dex/config.${AUTH_MODE}.yaml"
DEX_CERT_SOURCE="/workspace/ondemand/docker/config/dex/adfs-ntu.crt"
APP_OWNER="${OOD_CONTAINER_USER:-ooddev}"

resolve_app_owner() {
  local workspace="/workspace/ondemand"
  local owner_uid owner_gid owner_name owner_group

  owner_uid="$(stat -c '%u' "$workspace" 2>/dev/null || true)"
  owner_gid="$(stat -c '%g' "$workspace" 2>/dev/null || true)"

  if [ -n "$owner_uid" ] && [ -n "$owner_gid" ] && [ "$owner_uid" != "0" ]; then
    owner_name="$(getent passwd "$owner_uid" | cut -d: -f1 || true)"
    if [ -z "$owner_name" ]; then
      owner_group="$(getent group "$owner_gid" | cut -d: -f1 || true)"
      if [ -z "$owner_group" ]; then
        owner_group="oodhost"
        groupadd -g "$owner_gid" "$owner_group"
      fi

      owner_name="oodhost"
      if getent passwd "$owner_name" >/dev/null 2>&1; then
        owner_name="oodhost${owner_uid}"
      fi

      useradd -l -u "$owner_uid" --create-home --gid "$owner_gid" --shell /bin/bash "$owner_name"
    fi

    APP_OWNER="$owner_name"
    return
  fi

  if ! id "$APP_OWNER" >/dev/null 2>&1; then
    APP_OWNER="$(awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }' /etc/passwd)"
  fi

  if [ -z "$APP_OWNER" ]; then
    APP_OWNER="root"
  fi
}

resolve_app_owner

render_template() {
  local source="$1"
  local target="$2"

  cp "$source" "$target"

  render_placeholder "$target" "__OOD_DEX_CLIENT_SECRET__" "OOD_DEX_CLIENT_SECRET"
  render_placeholder "$target" "__OOD_LOCAL_DEX_CLIENT_SECRET__" "OOD_LOCAL_DEX_CLIENT_SECRET"
  render_placeholder "$target" "__OOD_LOCAL_PASSWORD__" "OOD_LOCAL_PASSWORD"
  render_placeholder "$target" "__OOD_LOCAL_PASSWORD_HASH__" "OOD_LOCAL_PASSWORD_HASH"
  render_placeholder "$target" "__OOD_LOCAL_USER_ID__" "OOD_LOCAL_USER_ID"
  render_placeholder "$target" "__OOD_LOCAL_BASE_URL__" "OOD_LOCAL_BASE_URL"
  render_placeholder "$target" "__OOD_LOCAL_HTTP_PORT__" "OOD_LOCAL_HTTP_PORT"
  render_placeholder "$target" "__OOD_SLURM_CLUSTER_TITLE__" "OOD_SLURM_CLUSTER_TITLE"
  render_placeholder "$target" "__OOD_SLURM_LOGIN_HOST__" "OOD_SLURM_LOGIN_HOST"
  render_placeholder "$target" "__OOD_SLURM_BIN__" "OOD_SLURM_BIN"
  render_placeholder "$target" "__OOD_SLURM_CONF__" "OOD_SLURM_CONF"
  render_placeholder "$target" "__OOD_SLURM_VNC_MODULE__" "OOD_SLURM_VNC_MODULE"
  render_slurm_cluster_option "$target"
  render_slurm_submit_host_option "$target"
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

render_slurm_cluster_option() {
  local target="$1"
  local token="__OOD_SLURM_CLUSTER_OPTION__"

  if ! grep -q "$token" "$target"; then
    return
  fi

  local cluster="${OOD_SLURM_CLUSTER_NAME:-}"
  if [ -z "$cluster" ]; then
    sed -i "/${token}/d" "$target"
    return
  fi

  local escaped="${cluster//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//#/\\#}"
  sed -i "s#${token}#cluster: \"${escaped}\"#g" "$target"
}

render_slurm_submit_host_option() {
  local target="$1"
  local token="__OOD_SLURM_SUBMIT_HOST_OPTION__"

  if ! grep -q "$token" "$target"; then
    return
  fi

  local submit_host="${OOD_SLURM_SUBMIT_HOST:-}"
  if [ -z "$submit_host" ]; then
    sed -i "/${token}/d" "$target"
    return
  fi

  local escaped="${submit_host//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//#/\\#}"
  sed -i "s#${token}#submit_host: \"${escaped}\"#g" "$target"
}

prepare_cluster_config() {
  mkdir -p /etc/ood/config/clusters.d

  if [ -d "$CONFIG_SOURCE/clusters.d" ]; then
    find "$CONFIG_SOURCE/clusters.d" -maxdepth 1 -type f -name '*.yml' \
      -exec cp {} /etc/ood/config/clusters.d/ \;
  fi

  if [ "${OOD_ENABLE_SLURM:-false}" != "true" ]; then
    return
  fi

  rm -f /etc/ood/config/clusters.d/localhost.yml

  local template="$CONFIG_SOURCE/clusters.d/slurm.yml.template"
  if [ ! -f "$template" ]; then
    echo "Missing Slurm cluster template: $template" >&2
    exit 1
  fi

  OOD_SLURM_CLUSTER_ID="${OOD_SLURM_CLUSTER_ID:-eecorehpc}"
  OOD_SLURM_CLUSTER_TITLE="${OOD_SLURM_CLUSTER_TITLE:-EE Core HPC}"
  OOD_SLURM_LOGIN_HOST="${OOD_SLURM_LOGIN_HOST:-eecorehpc.ee.ntu.edu.tw}"
  OOD_SLURM_SUBMIT_HOST="${OOD_SLURM_SUBMIT_HOST-}"
  OOD_SLURM_BIN="${OOD_SLURM_BIN:-/opt/hpc/slurm/bin}"
  OOD_SLURM_CONF="${OOD_SLURM_CONF:-/etc/slurm/slurm.conf}"
  OOD_SLURM_VNC_MODULE="${OOD_SLURM_VNC_MODULE:-ondemand-vnc}"

  export OOD_SLURM_CLUSTER_ID
  export OOD_SLURM_CLUSTER_TITLE
  export OOD_SLURM_LOGIN_HOST
  export OOD_SLURM_SUBMIT_HOST
  export OOD_SLURM_BIN
  export OOD_SLURM_CONF
  export OOD_SLURM_VNC_MODULE

  render_template "$template" "/etc/ood/config/clusters.d/${OOD_SLURM_CLUSTER_ID}.yml"

  if [ -n "$OOD_SLURM_SUBMIT_HOST" ] && command -v ssh-keyscan >/dev/null 2>&1; then
    mkdir -p /etc/ssh
    touch /etc/ssh/ssh_known_hosts
    ssh-keyscan -H "$OOD_SLURM_SUBMIT_HOST" >> /etc/ssh/ssh_known_hosts 2>/dev/null || true
    sort -u /etc/ssh/ssh_known_hosts -o /etc/ssh/ssh_known_hosts
    chmod 644 /etc/ssh/ssh_known_hosts
  fi
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

prepare_cluster_config

if [ -d /usr/local/host-slurm ] && command -v sudo >/dev/null 2>&1 && command -v nsenter >/dev/null 2>&1; then
  cat > /etc/sudoers.d/ood-host-slurm <<'EOF'
Defaults!/usr/bin/nsenter !requiretty
ALL ALL=(root) NOPASSWD: /usr/bin/nsenter *
EOF
  chmod 440 /etc/sudoers.d/ood-host-slurm
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
  chown -R "$APP_OWNER:$APP_OWNER" "$dashboard_dir/app/assets/builds" "$dashboard_dir/tmp" "$dashboard_dir/node_modules" 2>/dev/null || true
  chmod 777 "$dashboard_dir/tmp" "$dashboard_dir/tmp/cache" "$dashboard_dir/tmp/cache/assets" 2>/dev/null || true
  chmod 777 "$dashboard_dir/app/assets/builds" 2>/dev/null || true
  find "$dashboard_dir/tmp/cache/assets" -type d -exec chmod 777 {} + 2>/dev/null || true
  find "$dashboard_dir/tmp/cache/assets" -type f -exec chmod 666 {} + 2>/dev/null || true

  su -s /bin/bash -c "
    set -euo pipefail
    cd '$dashboard_dir'
    npm install --no-package-lock --no-fund --no-audit >/tmp/dashboard-npm-install.log 2>&1
    npm run build >/tmp/dashboard-npm-build.log 2>&1
    npm run build:css >/tmp/dashboard-npm-css.log 2>&1
  " "$APP_OWNER"
}

install_sys_app_bundles() {
  local app

  for app in dashboard myjobs; do
    local app_dir="/var/www/ood/apps/sys/$app"

    if [ ! -f "$app_dir/Gemfile" ]; then
      continue
    fi

    mkdir -p "$app_dir/.bundle" "$app_dir/vendor" "$app_dir/tmp" "$app_dir/log"
    chown -R "$APP_OWNER:$APP_OWNER" "$app_dir/.bundle" "$app_dir/vendor" "$app_dir/tmp" "$app_dir/log" 2>/dev/null || true

    su -s /bin/bash -c "
      set -euo pipefail
      cd '$app_dir'
      bundle check || bundle install --jobs 4 --retry 2
    " "$APP_OWNER"
  done
}

install_sys_app_bundles
build_dashboard_assets

/opt/ood/ood-portal-generator/sbin/update_ood_portal

if [ -f /etc/httpd/conf.d/ood-portal.conf.new ]; then
  cp /etc/httpd/conf.d/ood-portal.conf.new /etc/httpd/conf.d/ood-portal.conf
fi

# The container sits behind the host's TLS terminator, so serve plain HTTP on
# the internal port and let Apache talk to the local Dex instance directly.
sed -i 's#<VirtualHost \*:443>#<VirtualHost *:18080>#' /etc/httpd/conf.d/ood-portal.conf
if [ "$AUTH_MODE" = "local" ] && [ -n "${OOD_LOCAL_HTTP_PORT:-}" ]; then
  sed -i "s#<VirtualHost \\*:${OOD_LOCAL_HTTP_PORT}>#<VirtualHost *:18080>#" /etc/httpd/conf.d/ood-portal.conf
fi
sed -i '/Header always set Strict-Transport-Security/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/SSLEngine On/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/SSLCertificateFile/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/SSLCertificateKeyFile/d' /etc/httpd/conf.d/ood-portal.conf
sed -i 's#^  OIDCProviderMetadataURL .*#  OIDCProviderMetadataURL http://localhost:5556/dex/.well-known/openid-configuration#' /etc/httpd/conf.d/ood-portal.conf

# Keep the custom public landing page as the first page, matching the live site.
sed -i '/RedirectMatch \^\/\$ "\/pun\/sys\/dashboard"/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/RewriteRule \^\/\$ \/public\/index.html \[PT,L\]/d' /etc/httpd/conf.d/ood-portal.conf
sed -i '/RewriteRule \^(.\*) .* \[R=301,NE,L\]/a\  RewriteRule ^/$ /public/index.html [PT,L]' /etc/httpd/conf.d/ood-portal.conf

if [ -f "$DEX_TEMPLATE" ]; then
  mkdir -p /etc/ood/dex
  render_template "$DEX_TEMPLATE" /etc/ood/dex/config.yaml
  chown ondemand-dex:ondemand-dex /etc/ood/dex/config.yaml
  chmod 600 /etc/ood/dex/config.yaml
fi

mkdir -p /run/httpd

/usr/sbin/ondemand-dex serve /etc/ood/dex/config.yaml >/var/log/ondemand-dex.log 2>&1 &

exec /usr/sbin/httpd -DFOREGROUND
