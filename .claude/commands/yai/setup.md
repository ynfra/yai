---
description: First-time setup of the yai stack — generate secrets, init data dirs, start all services
argument-hint: ""
allowed-tools: Read, Bash, Edit, Write
---

Act as a senior operator setting up the yai stack. Goal: a fully running
stack with strong secrets and every service healthy.

**This command is idempotent and re-runnable.** The repo may be a clean clone
*or* a previously-configured stack that is merely stopped. Do **not** assume a
clean clone — detect existing state first (Step 0) and never destroy
working state. Verify actual container health, not just `doctor`'s coarse
`UP`/`PARTIAL`.

User input: $ARGUMENTS

## Prerequisites check

```sh
./yai.sh doctor
```

Abort with a clear error if `docker CLI` or `docker compose` is missing, or if
`jq` is missing (install: `sudo apt-get install -y jq`).

**Docker permissions (OrbStack).** On this host the user is typically in the
`orbstack` group, *not* `docker`, so the socket is `root:docker` and bare
`docker`/`./yai.sh` commands fail with `permission denied` — `doctor` then
reports `docker daemon FAIL` + `docker group FAIL`. `newgrp docker` does **not**
help when the user was never added to the `docker` group. The reliable fix
(the user has `sudo`) is to prefix **every** invocation:

```sh
sudo sg docker -c "./yai.sh init all"
sudo sg docker -c "./yai.sh start postgres"
sudo sg docker -c "docker exec yai-postgres psql -U yai -d yai -c '...'"
```

After this, `doctor` shows `docker daemon OK` and a benign `docker group WARN
(root not in group)` — that warning is expected and not a failure. (Permanent
fix, optional: `sudo usermod -aG docker $USER` then re-login.)

## Step 0 — Detect existing state (decides what's needed)

```sh
# secrets already generated? (count remaining placeholders, never print values)
for s in postgres minio n8n litellm langfuse windmill browserless firecrawl; do
  printf "%-12s change_me(.env)=%s  .env.local-keys=%s\n" "$s" \
    "$(grep -ci change_me $s/.env 2>/dev/null)" \
    "$(grep -c '=' $s/.env.local 2>/dev/null || echo 0)"
done
# shared postgres already initialized?
echo "postgres/data entries: $(ls -A postgres/data 2>/dev/null | wc -l)"
```

Interpret:
- **`.env.local` already populated and no `change_me` left** → secrets exist.
  **Skip Step 1.** Do **not** regenerate — that would desync from already
  initialized databases.
- **`postgres/data` non-empty** → the shared postgres is already initialized
  with its existing password. **Do not wipe it** and ignore the "must be empty"
  note in Step 2.

Only run Step 1 for services whose `.env.local` is missing/placeholder.

## Step 1 — Generate secrets into `.env.local` (only if missing)

`yai.sh` loads `.env` then `.env.local` via `--env-file`; the **later wins**,
so the effective value is whatever is in `.env.local`. Real secrets go in
**`.env.local`** (gitignored). **Never edit or overwrite `.env`** — it holds
tracked `change_me` placeholders only. To set a value, write/append the key in
`<service>/.env.local`.

**Use hex, never base64, for any secret embedded in a URL or route path.**
`openssl rand -hex 32` is safe everywhere. `openssl rand -base64 32` produces
`+ / =` which break `postgresql://user:pw@host` DSN parsing, and weak values
with `!` `*` `(` `)` break path-to-regexp route registration (e.g. firecrawl's
`BULL_AUTH_KEY` is interpolated into `/admin/<KEY>/...` and a `!` crashes the
API on boot). Affected keys that MUST be `[A-Za-z0-9]` only: every
`POSTGRES_PASSWORD`, `BULL_AUTH_KEY`, and anything used in a connection string.

| Service | Keys to set (in `.env.local`) |
|---------|------------|
| `postgres` | `POSTGRES_PASSWORD` |
| `n8n` | `POSTGRES_PASSWORD`, `ENCRYPTION_KEY`, `RUNNERS_AUTH_TOKEN` |
| `litellm` | `LITELLM_MASTER_KEY` (`sk-` prefix), `LITELLM_SALT_KEY`, `DATABASE_URL` (uses postgres password) |
| `langfuse` | `NEXTAUTH_SECRET`, `SALT`, `ENCRYPTION_KEY` (64-char hex), `POSTGRES_PASSWORD`, `CLICKHOUSE_PASSWORD`, `MINIO_ROOT_USER` (`langfuse`), `MINIO_ROOT_PASSWORD`, `REDIS_AUTH` |
| `windmill` | `POSTGRES_PASSWORD` |
| `browserless` | `BROWSERLESS_TOKEN` |
| `firecrawl` | `POSTGRES_PASSWORD`, `BULL_AUTH_KEY` |

> Note: `ENCRYPTION_KEY`/`SALT` (n8n, langfuse) encrypt stored data. Once a
> service has run, rotating these orphans existing encrypted credentials/traces.
> Set them once at first init; do not rotate on a re-run.

LiteLLM's `DATABASE_URL` in `litellm/.env.local` must reuse the **same**
`POSTGRES_PASSWORD` set in `postgres/.env.local`:
```
DATABASE_URL=postgresql://yai:<pg_password>@host.docker.internal:25432/litellm
```

After updating `.env.local` files, update `env.sh`:
- `YAI_POSTGRES_PASSWORD` → the postgres password
- `YAI_LITELLM_MASTER_KEY` → the master key

## Step 2 — Init data directories

```sh
sudo sg docker -c "./yai.sh init all"
```

Creates all bind-mount dirs and the `yai-infra` network, and applies ownership
for non-root UIDs (ClickHouse 101, Grafana 472, n8n chmod 777). It is
idempotent and safe to re-run.

**Clean clone only:** `postgres/data/` must be empty before the very first
start. **If it is already populated (Step 0), leave it** — wiping it destroys
the database and desyncs the password.

## Step 3 — Start postgres, ensure litellm DB

```sh
sudo sg docker -c "./yai.sh start postgres"   # wait until 'Healthy'
# idempotent: create litellm DB only if absent
sudo sg docker -c "docker exec yai-postgres psql -U yai -d yai -tAc \
  \"SELECT 1 FROM pg_database WHERE datname='litellm'\" | grep -q 1 \
  || docker exec yai-postgres psql -U yai -d yai -c 'CREATE DATABASE litellm;'"
```

## Step 4 — Start remaining services

`start` takes **one service or `all`** (not a list). `all` walks every service
in dependency order (postgres → … → grafana/traefik) and is resilient: a
service that fails to start is reported at the end but does not abort the rest.

```sh
sudo sg docker -c "./yai.sh start all"
```

(postgres is already up from Step 3; `up -d` is idempotent and skips it.) To
bring up a single service, name it: `./yai.sh start langfuse`. If `start all`
ends with `failed to start: <svc> …`, start that one service alone and read its
logs (see troubleshooting below).

> **`./yai.sh restart` does NOT reload `.env`/`.env.local`** — it runs
> `compose restart`, which reuses the existing container env. To apply any
> secret/env change you must `stop` then `start` (down/up):
> `sudo sg docker -c "./yai.sh stop <svc> && ./yai.sh start <svc>"`.

## Step 5 — Verify (inspect real container health)

`doctor`'s `UP`/`PARTIAL` is coarse — a crash-looping app inside a
multi-container project can still read as `PARTIAL` or even `UP`. Inspect every
container:

```sh
sudo sg docker -c "./yai.sh doctor"
sudo sg docker -c "docker ps -a --format '{{.Names}}\t{{.Status}}'" | sort
```

Flag anything `Restarting`, `unhealthy`, or `Exited` **except** the expected
one-shot init containers, which exit 0 by design:
- `yai-minio-init` — seeds buckets, then exits.
- `yai-langfuse-createbuckets` — seeds langfuse MinIO, then exits.

Optional HTTP smoke (200/301/401 = responding): litellm `:24000/health/liveliness`,
langfuse `:23000/api/public/health`, windmill `:28000/api/version`, grafana
`:22000/api/health`, qdrant `:26000/healthz`, n8n `:26002/healthz`, minio
`:25000/minio/health/live`, traefik `:80/` (the nav dashboard is on **:80**,
not 27000; traefik API is `:27001`).

### Troubleshooting — embedded-postgres "password authentication failed"

`windmill`, `firecrawl`, and `langfuse` each run their **own** postgres
(at `<svc>/data/postgres`), distinct from the shared `postgres/`. The embedded
DB bakes in `POSTGRES_PASSWORD` only on **first init** of an empty data dir. If
that dir was initialized under a *different* password than the current
`.env.local` (e.g. a prior aborted setup, or `.env`'s placeholder), the app
crash-loops:
- windmill/firecrawl: `password authentication failed for user "postgres"`
- langfuse: `P1000: Authentication failed ... credentials for 'langfuse'`

Since these embedded DBs hold no real data until the app connects, reset them:
```sh
sudo sg docker -c "./yai.sh stop <svc>"
sudo rm -rf <svc>/data/postgres          # embedded cluster ONLY (langfuse: keep clickhouse/minio/redis)
sudo sg docker -c "./yai.sh start <svc>" # re-inits with the current .env.local password
```
First confirm the password is `[A-Za-z0-9]`-only (Step 1) — a base64/`!`-laced
password will keep failing even after a wipe.

## Post-setup notes

- **Langfuse API keys** (`YAI_LANGFUSE_PUBLIC_KEY`/`_SECRET_KEY` in `env.sh`):
  project-level, generated after first login → `http://localhost:23000` →
  Settings → API Keys → paste into `env.sh`.
- **Grafana token** (`YAI_GRAFANA_TOKEN`): `http://localhost:22000` →
  Administration → Service accounts → token → `env.sh`.
- **LiteLLM models**: add provider keys to `litellm/.env.local` and routes to
  `litellm/config.yml`.

## Output format

```
Setup complete ✓

Services (16):
  postgres    UP  healthy
  minio       UP  healthy   (yai-minio-init exited 0 — expected)
  ...

Next steps:
  1. Add LiteLLM provider keys → litellm/config.yml + litellm/.env.local
  2. Langfuse API keys → http://localhost:23000 → Settings → API Keys → env.sh
  3. Grafana token → http://localhost:22000 → Administration → Service accounts → env.sh
```
