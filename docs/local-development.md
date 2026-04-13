# Local Development

Use Docker Compose for day-to-day work so changes happen locally and generated
runtime config stays out of git.

## First start

```bash
cd /storage/admin/misaki/ondemand
docker compose build
OOD_AUTH_MODE=local docker compose up -d
```

Open `http://localhost:18080`.

The local auth mode is intentionally disposable:

- Email: `misaki@localhost`
- Password: the `OOD_LOCAL_PASSWORD` value in your untracked `.env`
- OIDC client secret: the `OOD_LOCAL_DEX_CLIENT_SECRET` value in your untracked `.env`

Do not use the local password or client secret outside a development container.

## NTU SSO mode

Create an untracked `.env` file before starting either local auth or SSO:

```bash
OOD_AUTH_MODE=ntu-sso
OOD_DEX_CLIENT_SECRET=replace-with-rotated-secret
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
docker compose exec ondemand bash
docker compose down
docker compose down -v
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
