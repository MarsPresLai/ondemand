# Local Docker Workflow

This repo now includes a local Docker setup that mounts the merged source from
`~/ondemand` directly into `/var/www/ood` inside the container, so testing uses
the same code you will eventually sync back to the host deployment.

## Start

```bash
docker compose build
docker compose --profile dev up -d ondemand-dev
```

## Auth Modes

- Production: `ondemand-prod`
  This sends users from the landing page into Open OnDemand and then straight to
  the NTU SSO handoff without showing the Dex login screen.
- Development: `ondemand-dev`
  This keeps the local Dex password login for development and recovery.

```bash
docker compose --profile dev up -d ondemand-dev
```

For `ntu-sso`, put the Dex client secret in an untracked `.env` file or export
it in the shell:

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

## Login

- URL: `http://localhost:18080`
- Production: click the NTU login button and you should be handed directly
  to the school SSO flow.
- Development URL: `http://localhost:18081`
- Development:
  Email: `ooddev@localhost`
  Password: the `OOD_LOCAL_PASSWORD` value from your untracked `.env`

Update `docker/config/ood_portal.local.yml`
and `docker/config/dex/config.local.yaml`
if you want different local Dex credentials.

See `docs/local-development.md`
and `docs/production.md` before
pushing or deploying changes.

## Useful Commands

```bash
docker compose logs -f
docker compose logs -f ondemand-prod
docker compose --profile dev logs -f ondemand-dev
docker compose exec ondemand-prod bash
```

## Mounted Paths

- `apps/dashboard`
- `apps/myjobs`
- `apps/shell`
- `apps/bc_desktop`
- `docker/public/index.html`
- `docker/config/ood_portal.yml`
