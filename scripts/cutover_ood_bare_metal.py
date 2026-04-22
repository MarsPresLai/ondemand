#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path


REPO_ROOT = Path("/storage/admin/misaki/ondemand")
ENV_PATH = REPO_ROOT / ".env"
BACKUP_ROOT = Path("/etc/ood/migration-backups")
HOSTNAME = "eecorehpc.ee.ntu.edu.tw"


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def backup_file(path: Path, backup_dir: Path, name: str | None = None) -> None:
    if not path.exists():
        return
    backup_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backup_dir / (name or path.name))


def write_text(path: Path, content: str, mode: int, uid: int = 0, gid: int = 0) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    os.chown(path, uid, gid)
    os.chmod(path, mode)


def main() -> int:
    parser = argparse.ArgumentParser(description="Cut over OOD from Docker proxying to bare metal services.")
    parser.add_argument(
        "--backup-dir",
        default="20260422-bare-metal",
        help="Backup directory name under /etc/ood/migration-backups",
    )
    args = parser.parse_args()

    env = parse_env(ENV_PATH)
    secret = env["OOD_DEX_CLIENT_SECRET"]
    cluster_id = env.get("OOD_SLURM_CLUSTER_ID", "ntueecore") or "ntueecore"
    cluster_title = env.get("OOD_SLURM_CLUSTER_TITLE", "NTU EE Core HPC") or "NTU EE Core HPC"
    cluster_name = env.get("OOD_SLURM_CLUSTER_NAME", "ntueecore") or "ntueecore"
    login_host = env.get("OOD_SLURM_LOGIN_HOST", "localhost") or "localhost"
    vnc_module = env.get("OOD_SLURM_VNC_MODULE", "ondemand-vnc") or "ondemand-vnc"

    backup_dir = BACKUP_ROOT / args.backup_dir

    portal_path = Path("/etc/ood/config/ood_portal.yml")
    cluster_path = Path(f"/etc/ood/config/clusters.d/{cluster_id}.yml")
    pre_hook_dst = Path("/var/www/ood/bin/ood_pun_pre_hook.sh")
    dex_binary_dst = Path("/var/www/ood/bin/ondemand-dex-patched")
    apache_vhost = Path("/etc/apache2/sites-available/ood-portal.conf")
    override_path = Path("/etc/systemd/system/ondemand-dex.service.d/override.conf")

    backup_file(portal_path, backup_dir, "ood_portal.yml.bak")
    backup_file(cluster_path, backup_dir, f"{cluster_id}.yml.bak")
    backup_file(pre_hook_dst, backup_dir, "ood_pun_pre_hook.sh.bak")
    backup_file(apache_vhost, backup_dir, "ood-portal.conf.bak")
    backup_file(override_path, backup_dir, "ondemand-dex.override.conf.bak")

    ood_portal = f"""---
servername: {HOSTNAME}

ssl:
  - 'SSLCertificateFile "/etc/ssl/ood/eecorehpc.crt"'
  - 'SSLCertificateKeyFile "/etc/ssl/ood/eecorehpc.key"'

lua_root: /opt/ood/mod_ood_proxy/lib
lua_log_level: warn

user_map_match: '^([^@]+)@ntu\\.edu\\.tw$'

pun_stage_cmd: sudo /opt/ood/nginx_stage/sbin/nginx_stage

auth:
  - "AuthType openid-connect"
  - "Require valid-user"

oidc_uri: /oidc
oidc_remote_user_claim: email
oidc_settings:
  OIDCCookieSameSite: "Off"

dex_uri: /dex
dex:
  ssl: false
  http_port: "5556"
  client_id: {HOSTNAME}
  client_secret: {secret}
  client_redirect_uris:
    - https://{HOSTNAME}/oidc
    - https://{HOSTNAME}:443/oidc
  connectors:
    - type: saml
      id: ntu-adfs
      name: 台大帳號 (NTU SSO)
      config:
        ssoURL: https://adfs.ntu.edu.tw/adfs/ls/
        ca: /etc/ood/dex/adfs-ntu.crt
        redirectURI: https://{HOSTNAME}/dex/callback
        entityIssuer: https://{HOSTNAME}/dex/callback
        userIDAttr: "http://www.ntu.edu.tw/AccountName"
        usernameAttr: "http://www.ntu.edu.tw/AccountName"
        nameAttr: "http://www.ntu.edu.tw/ChineseName"
        emailAttr: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
        nameIDPolicyFormat: unspecified

node_uri: /node
rnode_uri: /rnode
host_regex: '[^/]+'

pun_pre_hook_root_cmd: /var/www/ood/bin/ood_pun_pre_hook.sh
pun_pre_hook_exports: OIDC_CLAIM_email,OIDC_CLAIM_name

custom_vhost_directives:
  - 'RewriteRule "^/$" "/public/index.html" [PT,L]'
  - 'Header always set Content-Security-Policy "frame-ancestors https://{HOSTNAME};"'
  - 'Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"'
"""

    cluster_config = f"""---
v2:
  metadata:
    title: "{cluster_title}"
    hidden: false
  login:
    host: "{login_host}"
  job:
    adapter: "slurm"
    cluster: "{cluster_name}"
    bin: "/usr/bin"
    conf: "/etc/slurm/slurm.conf"
  batch_connect:
    basic:
      script_wrapper: "module restore\\n%s"
    vnc:
      script_wrapper: "module restore\\nmodule load {vnc_module}\\n%s"
"""

    write_text(portal_path, ood_portal, 0o640)
    write_text(cluster_path, cluster_config, 0o644)

    pre_hook_src = REPO_ROOT / "bin" / "ood_pun_pre_hook.sh"
    shutil.copy2(pre_hook_src, pre_hook_dst)
    os.chown(pre_hook_dst, 0, 0)
    os.chmod(pre_hook_dst, 0o755)

    dex_binary_src = REPO_ROOT / "docker" / "bin" / "ondemand-dex"
    shutil.copy2(dex_binary_src, dex_binary_dst)
    os.chown(dex_binary_dst, 0, 0)
    os.chmod(dex_binary_dst, 0o755)

    override = """[Service]
ExecStart=
ExecStart=/var/www/ood/bin/ondemand-dex-patched serve /etc/ood/dex/config.yaml
"""
    write_text(override_path, override, 0o644)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
