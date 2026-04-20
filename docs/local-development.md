# Local Development

Use Docker Compose for day-to-day work so changes happen locally and generated
runtime config stays out of git.

## First start

```bash
cd ondemand
docker compose build
docker compose --profile dev up -d ondemand-dev
```

Open `http://localhost:18081`.

The local auth mode is intentionally disposable:

- Email: `ooddev@localhost`
- Password: the `OOD_LOCAL_PASSWORD` value in your untracked `.env`
- OIDC client secret: the `OOD_LOCAL_DEX_CLIENT_SECRET` value in your untracked `.env`

Do not use the local password or client secret outside a development container.

## NTU SSO mode

Create an untracked `.env` file before starting either local auth or SSO:

```bash
OOD_AUTH_MODE=ntu-sso
OOD_DEX_CLIENT_SECRET=replace-with-rotated-secret
OOD_PROD_CONTAINER_NAME=ondemand-prod
OOD_PROD_HTTP_PORT=18080
OOD_PROD_DEX_PORT=15556
OOD_DEV_CONTAINER_NAME=ondemand-dev
OOD_DEV_HTTP_PORT=18081
OOD_DEV_DEX_PORT=15557
OOD_DEV_USER=ooddev
OOD_DEV_UID=1000
OOD_DEV_GID=1000
OOD_LOCAL_BASE_URL=http://localhost:18081
OOD_LOCAL_HTTP_PORT=18081
OOD_LOCAL_DEX_CLIENT_SECRET=replace-with-local-secret
OOD_LOCAL_PASSWORD=replace-with-local-password
OOD_LOCAL_PASSWORD_HASH=replace-with-bcrypt-hash
OOD_LOCAL_USER_ID=replace-with-local-user-id
OOD_ENABLE_SLURM=false
OOD_SLURM_CLUSTER_ID=eecorehpc
OOD_SLURM_CLUSTER_TITLE=EE Core HPC
OOD_SLURM_CLUSTER_NAME=
OOD_SLURM_LOGIN_HOST=eecorehpc.ee.ntu.edu.tw
OOD_SLURM_SUBMIT_HOST=eecorehpc.ee.ntu.edu.tw
OOD_SLURM_BIN=/opt/hpc/slurm/bin
OOD_SLURM_CONF=/etc/slurm/slurm.conf
OOD_SLURM_VNC_MODULE=ondemand-vnc
```

Then run:

```bash
docker compose up -d
```

`docker/start-ondemand.sh` renders the secret into `/etc/ood/config` and
`/etc/ood/dex/config.yaml` inside the container only. It should not write the
secret back into `docker/config`.

## Useful commands

```bash
docker compose logs -f
docker compose logs -f ondemand-dev
docker compose exec ondemand-dev bash
docker compose --profile dev stop ondemand-dev
```

## Pre-push check

Run this before pushing local work:

```bash
git status --short
git diff --check
rg -n -i --hidden --glob '!.git/**' --glob '!node_modules/**' --glob '!vendor/**' \
  '(client_secret:|private[_-]?key|api[_-]?key|password:|token:|AKIA|github_pat_|ghp_|sk-)'
```

Expected intentional matches include example files and tests. Real deployment
values belong in `.env` or the server's secret manager, not in tracked YAML.

## Slurm development

Leave `OOD_ENABLE_SLURM=false` until the dev container can access the Slurm
client configuration it needs. When ready, set `OOD_ENABLE_SLURM=true`, then run:

```bash
bin/validate-ood-config
docker compose build ondemand-dev
docker compose --profile dev up -d ondemand-dev
docker compose --profile dev exec ondemand-dev \
  ruby -ryaml -e 'c=YAML.safe_load_file("/etc/ood/config/clusters.d/eecorehpc.yml", aliases: true); abort unless c.dig("v2", "job", "submit_host")'
ssh eecorehpc.ee.ntu.edu.tw /opt/hpc/slurm/bin/scontrol ping
```

The full dev-to-production Slurm checklist is in
[`docs/slurm-ood-setup.md`](slurm-ood-setup.md).
