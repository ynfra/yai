# n8n — workflow automation (queue mode)

Low-code workflow automation platform. Runs in **queue mode** with an embedded
Postgres + Redis backend and **external task runners** so user-supplied code
(Code nodes, expressions) executes in isolated processes outside the main n8n
container.

## Architecture

Six containers on a single self-contained compose network:

| Container | Role |
|-----------|------|
| `postgres` | Backing DB for workflows, executions, credentials. |
| `redis` | Bull queue broker for distributing executions between main and workers. |
| `n8n` | Main process — UI, API, webhook receiver, scheduler, task broker. |
| `n8n-worker` | Executes queued workflow runs pulled from Redis. |
| `n8n-runner` | External task runner attached to `n8n` (runs Code-node JS in isolation). |
| `n8n-worker-runner` | External task runner attached to `n8n-worker`. |

External runners (`N8N_RUNNERS_MODE=external`) are the recommended setup since
n8n 1.69+: the main/worker containers stay read-only, and arbitrary user code
is sandboxed in the dedicated runner containers.

## Image

- `docker.n8n.io/n8nio/n8n:2.21.3`
- `n8nio/runners:2.21.3` (must match the main image tag)
- `postgres:17.10`
- `redis:7-alpine`

## Ports

| Host | Container | Service | Purpose |
|------|-----------|---------|---------|
| 26002 | 5678 | n8n | Editor UI, REST API, webhooks |

## Persistence

- `./data/postgres` → `/var/lib/postgresql/data` (workflows, executions, credentials)
- `./data/n8n` → `/home/node/.n8n` (config, encryption-key file, binary data)
- `./data/redis` → `/data` (queue state)

These paths are created by `../yai.sh ensure_data_dirs`.

## First-time setup

```bash
# 1. Rotate secrets in .env BEFORE first start:
#    - ENCRYPTION_KEY  — encrypts stored credentials. If you change it later
#                         you lose access to every credential already in the DB.
#    - RUNNERS_AUTH_TOKEN — auth between main/worker and their runners.
#    Both can be generated with:
openssl rand -hex 32

# 2. Set POSTGRES_PASSWORD in .env.

# 3. Init + start
../yai.sh init n8n
../yai.sh start n8n

# 4. Open the editor
open http://localhost:26002
```

The first request to the editor prompts you to create the owner account.

## Webhooks

The yai stack runs n8n on a self-contained network with **no Traefik**.
Webhooks are reachable on `http://<host>:26002/webhook/...`. If exposing the
instance externally (reverse proxy, tunnel, public IP), set `WEBHOOK_URL` in
`.env` so n8n generates correct webhook URLs in the editor:

```
WEBHOOK_URL=https://n8n.example.com/
N8N_EDITOR_BASE_URL=https://n8n.example.com/
```

## Docs & references

- n8n docs: <https://docs.n8n.io/>
- Docker install: <https://docs.n8n.io/hosting/installation/docker/>
- Queue mode: <https://docs.n8n.io/hosting/scaling/queue-mode/>
- Docker Hub: <https://hub.docker.com/r/n8nio/n8n>
- Releases (2.21.3 is current): <https://github.com/n8n-io/n8n/releases>

## Operational notes

- All containers run `read_only: true` with `tmpfs` for `/tmp` and the node
  cache; nothing writable on the container rootfs.
- Workers scale horizontally — add more `n8n-worker` replicas (and matching
  `n8n-worker-runner`s) to increase execution throughput.
- `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` so the main process stays
  responsive to UI/API/webhook traffic even when running heavy workflows.
- `N8N_PROXY_HOPS=1` is set in anticipation of running behind a future reverse
  proxy; harmless when accessed directly.
- Backups: `pg_dump` the `postgres` container and snapshot `./data/n8n`
  (contains the encryption key file). Don't back up `./data/redis` — queue
  state is ephemeral.
