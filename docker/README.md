# Local Docker Workflow

This repo now includes a local Docker setup that mounts the merged source from
`~/ondemand` directly into `/var/www/ood` inside the container, so testing uses
the same code you will eventually sync back to the host deployment.

## Start

```bash
docker compose build
OOD_AUTH_MODE=local docker compose up -d
```

## Auth Modes

- Default: `local`
  This keeps the local Dex password login for development and recovery.
- SSO: `ntu-sso`
  This sends users from the landing page into Open OnDemand and then straight to
  the NTU SSO handoff without showing the Dex login screen.

```bash
OOD_AUTH_MODE=local docker compose up -d
```

For `ntu-sso`, put the Dex client secret in an untracked `.env` file or export
it in the shell:

```bash
OOD_AUTH_MODE=ntu-sso
OOD_DEX_CLIENT_SECRET=replace-with-rotated-secret
OOD_LOCAL_DEX_CLIENT_SECRET=replace-with-local-secret
OOD_LOCAL_PASSWORD=replace-with-local-password
OOD_LOCAL_PASSWORD_HASH=replace-with-bcrypt-hash
OOD_LOCAL_USER_ID=replace-with-local-user-id
```

## Login

- URL: `http://localhost:18080`
- `ntu-sso` mode: click the NTU login button and you should be handed directly
  to the school SSO flow.
- `local` mode:
  Email: `misaki@localhost`
  Password: the `OOD_LOCAL_PASSWORD` value from your untracked `.env`

Update [ood_portal.local.yml](/storage/admin/misaki/ondemand/docker/config/ood_portal.local.yml)
and [config.local.yaml](/storage/admin/misaki/ondemand/docker/config/dex/config.local.yaml)
if you want different local Dex credentials.

See [local-development.md](/storage/admin/misaki/ondemand/docs/local-development.md)
and [production.md](/storage/admin/misaki/ondemand/docs/production.md) before
pushing or deploying changes.

## Useful Commands

```bash
docker compose logs -f
docker compose exec ondemand bash
docker compose down
```

## Mounted Paths

- [dashboard](/storage/admin/misaki/ondemand/apps/dashboard)
- [myjobs](/storage/admin/misaki/ondemand/apps/myjobs)
- [shell](/storage/admin/misaki/ondemand/apps/shell)
- [bc_desktop](/storage/admin/misaki/ondemand/apps/bc_desktop)
- [docker public index](/storage/admin/misaki/ondemand/docker/public/index.html)
- [docker config](/storage/admin/misaki/ondemand/docker/config/ood_portal.yml)
