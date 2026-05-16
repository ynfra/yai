---
name: postgres
description: Shared Postgres 17 on the yai stack — connection strings, psql recipes, yai DB layout, cross-network access from containers, pg_dump. Auto-load on Postgres, psql, SQL, database connection, DSN, pg_dump, yai-postgres questions.
when_to_use: Load when the user asks about Postgres connection strings, running psql queries, pg_dump, cross-container DB access, or the yai shared Postgres instance. Also load when any yai service (LiteLLM) has a database connectivity issue.
allowed-tools: Bash(psql *) Bash(docker exec *) Bash(curl *)
---

# Postgres

Shared PostgreSQL 17 instance. Host port 25432. Used by LiteLLM and ad-hoc workloads.
Other stacks (n8n, windmill, firecrawl, langfuse) embed their own separate Postgres — do not consolidate them here.

Credentials live in `postgres/.env` and are exported by `env.sh`:

| Env var | Value |
|---------|-------|
| `YAI_POSTGRES_HOST` | `localhost` |
| `YAI_POSTGRES_PORT` | `25432` |
| `YAI_POSTGRES_USER` | `yai` |
| `YAI_POSTGRES_PASSWORD` | from `postgres/.env` |
| `YAI_POSTGRES_DB` | `yai` |
| `YAI_POSTGRES_DSN` | full DSN assembled from above |

## psql

```sh
source ./env.sh

# Interactive shell
psql "$YAI_POSTGRES_DSN"

# One-shot query
psql "$YAI_POSTGRES_DSN" -c '\l'
psql "$YAI_POSTGRES_DSN" -c 'SELECT version();'

# Via docker exec (no host psql required)
docker exec -it yai-postgres psql -U yai -d yai -c '\dt'
```

## Common admin queries

```sql
-- List databases
\l

-- List tables in current DB
\dt

-- Active connections
SELECT pid, usename, application_name, state, query
FROM pg_stat_activity WHERE state != 'idle';

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- Table sizes
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;
```

## LiteLLM DB setup (first time only)

```sh
docker exec -it yai-postgres psql -U yai -d yai -c 'CREATE DATABASE litellm;'
# Then update litellm/.env: DATABASE_URL=postgresql://yai:<password>@host.docker.internal:25432/litellm
```

## Connecting from inside another container

Containers in other compose projects cannot use `localhost` — they must use the host bridge:

```
# macOS / OrbStack / Docker Desktop
host.docker.internal:25432

# Linux (without Docker Desktop)
<host-ip>:25432
```

LiteLLM already has `extra_hosts: host.docker.internal:host-gateway` in its compose file.

## pg_dump / restore

```sh
source ./env.sh

# Dump the yai database
pg_dump "$YAI_POSTGRES_DSN" > yai_$(date +%Y%m%d).sql

# Or via docker exec (no local pg_dump required)
docker exec yai-postgres pg_dump -U yai yai > yai_$(date +%Y%m%d).sql

# Restore
psql "$YAI_POSTGRES_DSN" < yai_20260101.sql
```

## Operational notes

- `shm_size: 1g` is configured — parallel queries need shared memory; the default 64 MB causes `could not resize shared memory segment` errors under load.
- `pg_isready` healthcheck blocks dependent services from starting.
- Container name: `yai-postgres`. Use this in `docker exec` commands.
- No backup automation is configured — schedule `pg_dump` externally or via n8n/Windmill.
- **initdb "directory is not empty" on first start**: Docker auto-creates bind-mount source paths before the container starts. If `docker-compose.yml` mounts `./data/socket:/var/run/postgresql`, Docker creates `data/socket/` on the host, making `data/` non-empty and causing initdb to fail. The socket mount must be a sibling path (e.g., `./socket:/var/run/postgresql`), not nested inside the data directory.
