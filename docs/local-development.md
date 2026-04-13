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
