# Slurm and Open OnDemand Setup

This repo keeps generated runtime config and credentials out of git. The tracked
files provide templates, and the untracked `.env` file controls what gets
rendered inside the container at startup.

References:

- Open OnDemand cluster config v2 documents the cluster file layout and the
  `job.adapter: slurm`, `bin`, `conf`, and optional `cluster` keys.
- Open OnDemand's Slurm guide notes that Slurm client commands and the matching
  Slurm/MUNGE configuration must be available to the OOD host.

## Files Added or Changed

- `.env.example` documents the local, production, and Slurm environment keys
  without real secrets.
- `Dockerfile.dev` installs Slurm and MUNGE client packages as a fallback.
- `docker/config/clusters.d/slurm.yml.template` is the OOD Slurm cluster
  template.
- `docker/start-ondemand.sh` renders the Slurm cluster file only when
  `OOD_ENABLE_SLURM=true`.
- `docker-compose.yml` passes the Slurm environment into both dev and production
  services.
- `bin/validate-ood-config` checks shell syntax, YAML parsing, rendered Slurm
  YAML, and Docker Compose syntax.

## Required `.env` Values

Copy `.env.example` to `.env` and fill in real values locally:

```bash
cp .env.example .env
```

For development, keep local auth and enable Slurm only after the Slurm client
configuration is available:

```bash
OOD_AUTH_MODE=local
OOD_ENABLE_SLURM=true
OOD_SLURM_CLUSTER_ID=eecorehpc
OOD_SLURM_CLUSTER_TITLE=EE Core HPC
OOD_SLURM_CLUSTER_NAME=
OOD_SLURM_LOGIN_HOST=eecorehpc.ee.ntu.edu.tw
OOD_SLURM_SUBMIT_HOST=eecorehpc.ee.ntu.edu.tw
OOD_SLURM_BIN=/opt/hpc/slurm/bin
OOD_SLURM_CONF=/etc/slurm/slurm.conf
OOD_SLURM_VNC_MODULE=ondemand-vnc
```

For production, keep SSO secrets in `.env`:

```bash
OOD_AUTH_MODE=ntu-sso
OOD_DEX_CLIENT_SECRET=replace-with-rotated-secret
OOD_ENABLE_SLURM=true
```

Do not commit `.env`, rendered `/etc/ood/config` files, Dex config, TLS private
keys, Slurm keys, or MUNGE keys.

## Dev Test First

Validate the config without printing secret values:

```bash
bin/validate-ood-config
```

Build and start the dev service:

```bash
docker compose build ondemand-dev
docker compose --profile dev up -d ondemand-dev
docker compose logs -f ondemand-dev
```

Confirm the rendered cluster exists inside dev:

```bash
docker compose --profile dev exec ondemand-dev \
  test -f /etc/ood/config/clusters.d/eecorehpc.yml
docker compose --profile dev exec ondemand-dev \
  ruby -ryaml -e 'YAML.safe_load_file("/etc/ood/config/clusters.d/eecorehpc.yml", aliases: true)'
```

Confirm the rendered Slurm cluster uses SSH submission:

```bash
docker compose --profile dev exec ondemand-dev \
  ruby -ryaml -e 'c=YAML.safe_load_file("/etc/ood/config/clusters.d/eecorehpc.yml", aliases: true); abort unless c.dig("v2", "job", "submit_host")'
```

Run scheduler smoke checks on the submit host:

```bash
ssh eecorehpc.ee.ntu.edu.tw /opt/hpc/slurm/bin/scontrol ping
ssh eecorehpc.ee.ntu.edu.tw '/opt/hpc/slurm/bin/sinfo -h -o "%P %a %D" | head -5'
```

The container seeds `/etc/ssh/ssh_known_hosts` with `ssh-keyscan` for
`OOD_SLURM_SUBMIT_HOST`. User authentication still has to be valid for the user
whose PUN is running. Configure host-based SSH, user keys, or another site
approved non-interactive SSH method before production Slurm submissions.

Only move to production after these dev checks pass.

## Production Rollout

Production uses the same tracked templates, but reads real values from `.env`.

```bash
git status --short --branch
bin/validate-ood-config
docker compose build ondemand-prod
docker compose up -d ondemand-prod
docker compose logs -f ondemand-prod
```

After production starts, verify the rendered cluster config and Slurm commands:
After production starts, verify the rendered cluster config and the remote Slurm
commands:

```bash
docker compose exec ondemand-prod \
  ruby -ryaml -e 'YAML.safe_load_file("/etc/ood/config/clusters.d/eecorehpc.yml", aliases: true)'
ssh eecorehpc.ee.ntu.edu.tw /opt/hpc/slurm/bin/scontrol ping
ssh eecorehpc.ee.ntu.edu.tw '/opt/hpc/slurm/bin/sinfo -h -o "%P %a %D" | head -5'
```

## Notes

Set `OOD_SLURM_CLUSTER_NAME` only for a multi-cluster Slurm setup where OOD
should pass `-M <cluster>` to Slurm. Leave it empty for a single Slurm cluster.

The shell app uses `OOD_SLURM_LOGIN_HOST`; make sure DNS and SSH reachability
work from the OOD container or host.

Interactive desktop sessions use `module restore` and then load
`OOD_SLURM_VNC_MODULE`. Change the module name in `.env` if the site uses a
different VNC module.
