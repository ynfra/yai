# windmill — workflow & script engine

Open-source developer platform for building internal tools, workflows, data
pipelines, and UIs from scripts written in TypeScript, Python, Go, Bash, SQL
or PHP. Positioned as a faster, self-hostable alternative to Airflow,
Temporal, and Retool — the project benchmarks itself as ~13× faster than
Airflow on equivalent DAG workloads.

## Architecture

Five containers on a single self-contained compose network:

| Container | Role |
|-----------|------|
| `postgres` | Backing DB — workflows, scripts, jobs, audit log, secrets (encrypted). |
| `windmill-server` | HTTP API, web UI, scheduler, job dispatcher. Serves :8000. |
| `windmill-worker` × 3 | Default workers — pull from the `default` queue. Each job runs in a sandboxed nsjail container. |
| `windmill-worker-native` × 1 | Native worker — runs lightweight scripts (TS/Python/Bash) in-process without spawning a sandbox. Fast for many small jobs. |

`WORKER_GROUP` on each worker determines which queue it pulls from:
`default` for the standard sandboxed workers, `native` for the in-process
worker. Adjust replica counts to scale throughput.

## Image

- `ghcr.io/windmill-labs/windmill:1.703.0` (server + all workers — single image, behaviour driven by `MODE` / `WORKER_GROUP`)
- `postgres:17.10`

### Pinning policy

Pin to an exact upstream release (`1.703.0`, `1.703.1`, …); never use
`latest` or a floating major. Windmill ships frequent point releases with
schema migrations — the version is the contract.

## Ports

| Host | Container | Service | Purpose |
|------|-----------|---------|---------|
| 28000 | 8000 | windmill-server | Web UI, REST API, webhooks |

Workers and Postgres are not published — they speak to the server over the
internal compose network only.

## Persistence

- `./data/postgres` → `/var/lib/postgresql/data` (workflows, jobs, secrets, audit log)
- `./data/cache` → `/tmp/windmill/cache` (worker dependency cache — pip/npm/cargo artifacts; shared by all default workers)
- `./data/logs` → `/tmp/windmill/logs` (per-job stdout/stderr, written by every server + worker)

These paths are created by `../yai.sh ensure_data_dirs`.

## First-time setup

```bash
# 1. Rotate POSTGRES_PASSWORD in .env (change_me → something real).
#    The POSTGRES_USER must remain `postgres` — Windmill's migrations
#    expect that role to own the database.

# 2. Init + start
../yai.sh init windmill
../yai.sh start windmill

# 3. Open the UI — the first request creates the admin user
open http://localhost:28000
```

There is no pre-seeded admin: the very first browser visit to the server
walks you through creating the initial superadmin account and default
workspace.

## Docs & references

- Intro: <https://www.windmill.dev/docs/intro>
- Self-host guide: <https://www.windmill.dev/docs/advanced/self_host>
- Source: <https://github.com/windmill-labs/windmill>
- Releases (1.703.0 is current): <https://github.com/windmill-labs/windmill/releases>

## Operational notes

- **Native vs default workers.** Default workers spawn an `nsjail` sandbox
  per job — strong isolation, ~hundreds of ms startup overhead. The native
  worker runs jobs in-process inside the worker container itself: no
  sandbox, no cold start, ideal for many short scripts (HTTP calls,
  transformations, glue code). Mark a script as `native` in the Windmill UI
  to route it to the `native` queue.
- **Read-only rootfs.** Server and Postgres run `read_only: true` with
  tmpfs mounts for `/tmp` and (on Postgres) `/var/run/postgresql`. Workers
  need a writable rootfs for nsjail and the dependency cache, so they are
  not marked read-only.
- **Dependency cache** (`./data/cache`) is shared between all default
  workers — first invocation of a script with new deps populates it,
  subsequent runs across any worker reuse it. Safe to delete; it will
  rebuild on demand.
- **Scaling.** Increase `windmill-worker` `deploy.replicas` for more
  default-queue throughput. The native worker already runs `NUM_WORKERS=8`
  threads inside its single container — bump that env var (or its replica
  count) for higher native concurrency.
- **No reverse proxy in this stack.** Windmill is exposed directly on
  host port `28000`. If you later front it with a tunnel or proxy, set
  `BASE_URL` in `.env` so Windmill emits correct webhook URLs.
- **Backups.** `pg_dump` the `postgres` container — that single dump
  contains every workflow, script, schedule, and (encrypted) secret.
  `./data/cache` and `./data/logs` are disposable.
