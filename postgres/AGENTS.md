# postgres — shared Postgres 17

Standalone PostgreSQL 17 instance used as the backing DB for the LiteLLM proxy
and as a general-purpose dev DB for ad-hoc workloads. Other stacks in this
project (n8n, windmill, firecrawl, langfuse) embed their own Postgres bound to
their internal network — those are independent of this instance.

## Image

- `postgres:17.10` — Docker Official Image
- Tag policy: pin to a minor version (`17.10`, `17.11`, …); avoid `17` floating.

## Ports

| Host | Container | Purpose |
|------|-----------|---------|
| 25432 | 5432 | SQL |

## Persistence

- `./data/` → `/var/lib/postgresql/data` (bind mount)

## First-time setup

```bash
# Set credentials in .env (change_me → something real)
../yai.sh init postgres
../yai.sh start postgres

# Verify
docker exec -it yai-postgres psql -U yai -d yai -c '\l'
```

## Connecting from other services

Other stacks in this repo run in their own compose networks. To reach this
Postgres from inside another container, target the host:

```
host.docker.internal:25432    # macOS / Docker Desktop
<host-ip>:25432               # Linux
```

For LiteLLM (which lives in `../litellm/`) the wiring is already set up via
`extra_hosts: host.docker.internal:host-gateway`.

## Docs & references

- Docker image: <https://hub.docker.com/_/postgres>
- Image source: <https://github.com/docker-library/postgres>
- PostgreSQL 17 release notes: <https://www.postgresql.org/docs/17/release.html>
- Upstream docs: <https://www.postgresql.org/docs/17/>

## Operational notes

- `shm_size: 1g` is set — Postgres parallel queries need shared memory; the
  default 64 MB will cause `could not resize shared memory segment` errors
  under load.
- `pg_isready` healthcheck blocks dependent services from starting until the
  DB is accepting connections.
- Backups are not configured here — run `pg_dump` manually or add a sidecar.
