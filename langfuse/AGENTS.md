# langfuse — LLM observability (v3, self-hosted)

Open-source LLM observability platform. Captures traces, metrics, evals,
prompt versions, and datasets from any LLM app via the Langfuse SDKs or
OTEL-compatible exporters. Self-hosted here — no data leaves the box.

## Architecture

Six containers on a single self-contained compose network. The v3 change
over v2 is the split data plane: trace ingestion writes to S3 (MinIO) +
ClickHouse via a background worker, while the relational state stays in
Postgres. ClickHouse turns "average latency over 30 days" from seconds
(v2 on Postgres) into milliseconds.

| Container | Role |
|-----------|------|
| `langfuse-web` | Next.js UI + REST/GraphQL API + SDK ingestion endpoint. Container port 3000. |
| `langfuse-worker` | Background jobs — trace ingestion, evals, batch exports, retention sweeps. Container port 3030. |
| `postgres` | Relational state — orgs, projects, users, prompts, datasets, settings, encrypted secrets. |
| `clickhouse` | Columnar OLAP store for traces, observations, scores. The performance core of v3. |
| `minio` | S3-compatible blob store for raw ingestion events and media (images/audio attached to traces). **Separate from `../minio/`** — that one is the shared MinIO; this one is private to Langfuse and bound to its own data dir. |
| `redis` | BullMQ queue between web and worker, plus rate-limit / cache. |

## Image versions & pinning

| Component | Image | Default tag |
|-----------|-------|-------------|
| langfuse-web | `docker.io/langfuse/langfuse` | `3` (floating major) |
| langfuse-worker | `docker.io/langfuse/langfuse-worker` | `3` (floating major) |
| postgres | `postgres` | `17.10` |
| clickhouse | `clickhouse/clickhouse-server` | `24.12-alpine` |
| minio | `bitnami/minio` | `latest` |
| redis | `redis` | `7-alpine` |

Tag policy: float on the Langfuse major (`3`) for quick patches; pin to the
exact release (`3.174.1` as of 2026-05-13) when you need reproducibility.
Backing stores (Postgres, ClickHouse, Redis) stay on pinned minors —
upgrading them requires checking Langfuse compatibility notes first.

> **Why bitnami/minio?** Upstream's docker-compose uses
> `cgr.dev/chainguard/minio`. The yai project standardises on Bitnami's
> MinIO image (see `../minio/`), so the env-var contract and `/bitnami/minio/data`
> mount path match across stacks. Functionally equivalent.

## Ports

Only two host ports are reachable from outside the loopback interface:

| Host | Container | Service | Exposure | Purpose |
|------|-----------|---------|----------|---------|
| 23000 | 3000 | langfuse-web | all interfaces | UI + ingestion API (used by SDK clients) |
| 23090 | 9000 | langfuse-minio | all interfaces | S3 API — required because media URLs are signed against this endpoint and fetched directly by the user's browser |
| 23030 | 3030 | langfuse-worker | 127.0.0.1 only | `/api/health` only — Langfuse v3 exposes no Prometheus `/metrics` endpoint |
| 23091 | 9001 | langfuse-minio | 127.0.0.1 only | MinIO admin console |
| —     | 5432 | postgres   | internal-only | — |
| —     | 8123/9000 | clickhouse | internal-only | — |
| —     | 6379 | redis      | internal-only | — |

If you put Langfuse behind a reverse proxy or change `LANGFUSE_WEB_PORT`,
update `NEXTAUTH_URL` in `.env` to match what the browser sees.

## Persistence

All state lives under `./data/` as bind mounts:

```
./data/
├── postgres/                    → /var/lib/postgresql/data   (relational state)
├── clickhouse/
│   ├── data/                    → /var/lib/clickhouse        (trace OLAP store)
│   └── logs/                    → /var/log/clickhouse-server
├── minio/                       → /bitnami/minio/data        (event + media blobs)
└── redis/                       → /data                       (queue state)
```

These paths are created by `../yai.sh ensure_data_dirs`.

Backups: dump `postgres` (`pg_dump`) and snapshot `./data/clickhouse/data`
and `./data/minio/` together — they're a consistency set. `./data/redis`
is ephemeral; don't bother.

## First-time setup

```bash
# 1. ROTATE every change_me in .env BEFORE the first start.
#    ENCRYPTION_KEY is irrecoverable — losing or rotating it later
#    permanently breaks every encrypted secret already in the DB.
#
#    NEXTAUTH_SECRET, SALT       — openssl rand -base64 32
#    ENCRYPTION_KEY              — openssl rand -hex 32   (MUST be 64 hex chars)
#    POSTGRES_PASSWORD,
#    CLICKHOUSE_PASSWORD,
#    MINIO_ROOT_USER/PASSWORD,
#    REDIS_AUTH                  — any random string (MinIO min 8 chars)

# 2. Init data dirs + start the stack
../yai.sh init langfuse
../yai.sh start langfuse

# 3. First boot does Prisma migrations on Postgres and the
#    `clickhouse-migrator` on ClickHouse — give it ~30s.
docker compose -p yai-langfuse logs -f langfuse-web

# 4. Open the UI and register the first user — that account becomes
#    the organisation owner.
open http://localhost:23000

# 5. Create a project → Settings → API Keys → generate a key pair.
#    Plug the public/secret pair into your SDK or LiteLLM config (below).
```

To skip the interactive owner registration, fill in the four
`LANGFUSE_INIT_*` vars in `.env` before first start.

## Wiring LiteLLM (../litellm) to Langfuse

Two options — pick one.

**Option A: env vars on the LiteLLM container.** Add to `../litellm/.env`:

```
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=http://host.docker.internal:23000
```

then add `langfuse` to the callbacks in `../litellm/config.yml`:

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
```

**Option B: bake the credentials into `config.yml`** under
`litellm_settings.langfuse_*` directly. Env vars are usually cleaner.

`../litellm/docker-compose.yml` already has
`extra_hosts: host.docker.internal:host-gateway`, so the LiteLLM container
can reach `langfuse-web` on the host port (`23000`) without putting the
two stacks on a shared network.

## Wiring application SDKs

Any Langfuse SDK (Python, JS, OTEL) needs three values:

```
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=http://localhost:23000          # from the host
LANGFUSE_HOST=http://host.docker.internal:23000   # from another container
```

## Docs & references

- Home: <https://langfuse.com/docs>
- Self-hosting overview: <https://langfuse.com/self-hosting>
- Docker Compose guide: <https://langfuse.com/self-hosting/deployment/docker-compose>
- Configuration reference: <https://langfuse.com/self-hosting/configuration>
- GitHub: <https://github.com/langfuse/langfuse>
- Releases (latest stable v3.174.1 on 2026-05-13): <https://github.com/langfuse/langfuse/releases>
- v2 → v3 migration: <https://langfuse.com/self-hosting/upgrade-guides/upgrade-v2-to-v3>

## Operational notes

- `langfuse-worker` is the only container that talks to ClickHouse for
  ingestion — scaling ingestion = adding worker replicas, not web replicas.
- ClickHouse is single-node here (`CLICKHOUSE_CLUSTER_ENABLED=false`).
  For HA you'd switch to a Keeper-backed cluster; out of scope for yai.
- The MinIO bucket `langfuse` is created on first boot by the Bitnami
  `MINIO_DEFAULT_BUCKETS` hook — no manual `mc mb` step needed.
- Media-upload URLs are signed against
  `LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT=http://localhost:23090`, so users
  fetching images attached to a trace need network access to that port.
  If you reverse-proxy MinIO, update that env var to the public URL.
- Redis runs `--maxmemory-policy noeviction` — required so BullMQ jobs
  aren't silently dropped under memory pressure. Watch the container's
  memory usage if you push high trace volume.
- Telemetry: `TELEMETRY_ENABLED=true` sends anonymised usage stats to
  Langfuse Cloud. Flip to `false` in the compose file's `x-langfuse-env`
  block if you want it off.
