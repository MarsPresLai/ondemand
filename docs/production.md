# Production Deployment Notes

This repo should not contain live production secrets. Treat the NTU SSO Dex
client secret that was previously committed as exposed and rotate it before
pushing this branch to GitHub.

## Secret handling

Keep these values outside git:

- `OOD_DEX_CLIENT_SECRET`
- TLS private keys
- IdP client secrets
- Any generated Rails `SECRET_KEY_BASE` for production
- Host-specific override files

For the Docker workflow, provide the Dex client secret through the environment:

```bash
export OOD_AUTH_MODE=ntu-sso
export OOD_DEX_CLIENT_SECRET='replace-with-rotated-secret'
export OOD_PROD_CONTAINER_NAME=ondemand-prod
export OOD_PROD_HTTP_PORT=18080
export OOD_PROD_DEX_PORT=15556
export OOD_LOCAL_DEX_CLIENT_SECRET='replace-with-rotated-local-secret'
export OOD_LOCAL_PASSWORD='replace-with-rotated-local-password'
export OOD_LOCAL_PASSWORD_HASH='replace-with-rotated-local-bcrypt-hash'
export OOD_LOCAL_USER_ID='replace-with-rotated-local-user-id'
export OOD_ENABLE_SLURM=true
export OOD_SLURM_CLUSTER_ID=eecorehpc
export OOD_SLURM_CLUSTER_TITLE='EE Core HPC'
export OOD_SLURM_CLUSTER_NAME=
export OOD_SLURM_LOGIN_HOST=eecorehpc.ee.ntu.edu.tw
export OOD_SLURM_SUBMIT_HOST=eecorehpc.ee.ntu.edu.tw
export OOD_SLURM_BIN=/opt/hpc/slurm/bin
export OOD_SLURM_CONF=/etc/slurm/slurm.conf
export OOD_SLURM_VNC_MODULE=ondemand-vnc
docker compose up -d ondemand-prod
```

For a non-Docker host deployment, use the same principle: copy the tracked
templates into `/etc/ood/config` and `/etc/ood/dex`, replace placeholders on the
host, and keep the rendered files owned by root with restrictive permissions.
Do not copy rendered production config back into this repository.

## GitHub push checklist

Before pushing:

```bash
git status --short
git diff --check
git log --all -S'old-secret-value' --oneline
rg -n -i --hidden --glob '!.git/**' --glob '!node_modules/**' --glob '!vendor/**' \
  '(client_secret:|private[_-]?key|api[_-]?key|password:|token:|AKIA|github_pat_|ghp_|sk-)'
```

If `git log -S` finds a real secret in history, rotate the secret. Removing it
from the latest commit is not enough once it has existed in commit history.

## Deploying from this repo

Recommended flow:

```bash
git fetch origin
git status --short --branch
bin/validate-ood-config
docker compose build ondemand-prod
docker compose up -d ondemand-prod
docker compose logs -f ondemand-prod
```

Because this branch is currently behind upstream, merge or rebase upstream work
in a separate branch and retest SSO before using it as the live deployment
source.

## Slurm rollout

Slurm is rendered into `/etc/ood/config/clusters.d/<OOD_SLURM_CLUSTER_ID>.yml`
only when `OOD_ENABLE_SLURM=true`. Test it in `ondemand-dev` first, then start
`ondemand-prod` from the same `.env` values after validation passes.

The exact checklist is in [`docs/slurm-ood-setup.md`](slurm-ood-setup.md).
