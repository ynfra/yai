# AI Agent Instructions — yai

Self-hosted AI infrastructure stack. Each service is an isolated
docker-compose project under its own folder, managed by a single CLI
(`./yai.sh`). All data is bind-mounted to `./<service>/data/` and survives
container restarts.

## Architecture

```
       ┌──────────────────────────┐   ┌──────────────────────────┐
       │  LLM + observability     │   │  Browser fleet           │
       │  litellm (gateway)       │   │  browserless (generic)   │
       │  langfuse (traces/evals) │   │  firecrawl (crawl API)   │
       └──────────────────────────┘   └──────────────────────────┘
                          │                       │
                          ▼                       ▼
       ┌──────────────────────────────────────────────────────────┐
       │  Workflow & data                                         │
       │  n8n  •  windmill  •  qdrant  •  minio  •  postgres      │
       └──────────────────────────────────────────────────────────┘
                                  │
                                  ▼
       ┌──────────────────────────────────────────────────────────┐
       │  Observability  (all on yai-infra Docker network)       │
       │  grafana  •  vmetrics  •  vlogs  •  vtraces  •  vector │
       └──────────────────────────────────────────────────────────┘
```

Every service is reachable on its direct host port. Traefik also exposes all
services via `<service>.localhost` hostname routing on port 80 and a navigation
dashboard at `http://localhost` (port 80). Traefik's own API is on `:27001`.

## Services

| Service | Image (pinned) | Host ports | Description |
|---|---|---|---|
| `postgres` | `postgres:17.10` | 25432 | Shared Postgres 17 — used by LiteLLM and ad-hoc workloads. Other stacks bring their own embedded DB. |
| `minio` | `pgsty/minio:RELEASE.2026-04-17T00-00-00Z` | 25000 (S3), 25001 (console) | S3-compatible object storage. (Upstream `minio/minio` was archived 2026-04-25; pgsty/minio is the maintained fork used here.) |
| `qdrant` | `qdrant/qdrant:v1.13.1` | 26000 (REST), 26001 (gRPC) | Vector DB for RAG / embeddings. |
| `browserless` | `ghcr.io/browserless/chromium:latest` | 26003 | Generic headless Chromium API (Puppeteer / Playwright / CDP). Use for scripted scraping. |
| `firecrawl` | `ghcr.io/firecrawl/firecrawl:latest` | 21000 | Web scraping & crawling API (built-in queues, Playwright backend). No versioned GHCR tags published; `:latest` is the only option. |
| `n8n` | `docker.n8n.io/n8nio/n8n:2.21.3` | 26002 | Workflow automation (queue mode, postgres + redis + workers + runners). |
| `litellm` | `litellm/litellm:v1.85.0` | 24000 | OpenAI-compatible LLM gateway. Uses shared `postgres`. |
| `langfuse` | `langfuse/langfuse:3` (+worker, clickhouse, minio, redis, postgres) | 23000 (web), 23090 (media MinIO) | LLM observability — traces, evals, prompt mgmt. |
| `windmill` | `ghcr.io/windmill-labs/windmill:1.703.0` | 28000 | Workflow & script engine (postgres + 3 workers + native worker). |
| `vmetrics` | `victoriametrics/victoria-metrics:v1.143.0` | 28428 | Metrics store + built-in scraper (PromQL/MetricsQL). Scrape targets at `/targets`. |
| `vlogs` | `victoriametrics/victoria-logs:v1.50.0` | 29428 | Log store (Loki-compatible push, LogsQL query). |
| `vtraces` | `victoriametrics/victoria-traces:v0.8.2` | 21428 | Trace store (OTLP ingest, Jaeger-compatible query). |
| `vector` | `timberio/vector:0.44.0-debian` | _(none, internal)_ | Docker log collector — ships `yai-*` container logs to vlogs via Loki push. Exposes Prometheus metrics on `:9598` (scraped by vmetrics). |
| `node-exporter` | `prom/node-exporter:v1.9.1` | _(none, internal)_ | Prometheus Node Exporter — host OS metrics (CPU, memory, disk, network). Scraped by vmetrics as job `node_exporters`. |
| `grafana` | `grafana/grafana:12.4.3` | 22000 | Grafana UI. Queries obs services via the `yai-infra` Docker network. |
| `traefik` | `traefik:v3.3` (+ `nginx:1.27-alpine`) | 80 (HTTP), 27001 (API) | HTTP reverse proxy. Routes `*.localhost` and `*.yai.orb.local`; Prometheus metrics at `:27001/metrics`. |

## Directory layout

```
yai/
├── yai.sh                     # Management CLI
├── AGENTS.md  CLAUDE.md       # Agent rules
├── README.md
├── .gitignore
└── <service>/
    ├── docker-compose.yml
    ├── .env                   # Placeholder secrets (`change_me`) — replace before start
    ├── AGENTS.md              # Per-service docs + upstream links
    └── data/                  # Bind-mounted runtime state (gitignored)
```

Each service folder also supports an optional `.env.local` file that
overrides values from `.env` — gitignored, ideal for personal/dev tweaks.

## Management — `yai.sh`

```
yai stack <cmd>              operate on every service
yai service <name> <cmd>     operate on one service
yai <cmd> [service|all]      short form (same semantics as ydocker/server.sh)

Commands: init | start | stop | restart | logs | ps | status

Examples:
  ./yai.sh stack start
  ./yai.sh service n8n logs
  ./yai.sh service langfuse restart
  ./yai.sh start qdrant
  ./yai.sh stop all
```

### First-time setup

1. `./yai.sh init all` — creates every `./data/` tree and warns on
   `change_me` placeholders.
2. Edit each `<service>/.env` and replace every `change_me` value.
   - `postgres/.env`, `minio/.env`, `n8n/.env`, `litellm/.env`,
     `langfuse/.env`, `windmill/.env`, `grafana/.env` all have secrets.
   - Generate strong values with `openssl rand -hex 32` or `openssl rand -base64 32`.
3. Start `postgres` first if you plan to use `litellm` (which depends on it):
   ```bash
   ./yai.sh start postgres
   docker exec -it yai-postgres psql -U yai -d yai -c 'CREATE DATABASE litellm;'
   # then update litellm/.env DATABASE_URL → .../litellm
   ```
4. `./yai.sh stack start` — bring up the rest.

### Logs / debugging

```bash
./yai.sh logs n8n            # tail one service
./yai.sh ps all              # container status across the stack
./yai.sh service grafana ps  # alternative explicit form
```

## Persistent data

Every stateful service mounts a host directory under `./<service>/data/`. The
exact layout per service is documented in the service's own `AGENTS.md`. All
of these are gitignored. Do **not** delete anything under `data/` while the
service is running.

## LLM strategy

LiteLLM is the default gateway. Point all in-stack consumers
(n8n, windmill, firecrawl, langfuse SDK callers) at
`http://host.docker.internal:24000/v1` with the master key. Then configure
upstream provider keys (OpenRouter, OpenAI, Anthropic, …) in
`litellm/config.yml` and `litellm/.env`.

This server has no GPU — do **not** add Ollama, llama.cpp, LocalAI, or any
other local-model runtime. All inference is remote, brokered by LiteLLM.

## Browser strategy

Two Docker services plus a Claude Code skill:

| Tool | Role |
|---|---|
| **agent-browser** (skill) | **Control plane for LLM agents** — stateful Chromium daemon with annotated snapshots and `@ref` element addressing. Runs on the host, not in Docker. Skill at `.claude/skills/agent-browser/`. Install: `npm install -g agent-browser && agent-browser install`. |
| `browserless` | Generic Puppeteer/Playwright/CDP endpoint. Use for scripted scrapes, PDF/screenshot generation, n8n nodes. Stateless workers. |
| `firecrawl` | High-level crawl API: feed it a URL, get clean markdown + structured data. Built-in queues + Playwright backend. |

Rule of thumb: agent reasoning over a live page → `agent-browser` skill.
Scripted batch fetching → `browserless`. "Crawl this whole site and give me
markdown" → `firecrawl`.

## Observability

Six compose projects joined to the `yai-infra` Docker network:

| Service | Folder | Role |
|---------|--------|------|
| `vmetrics` | `vmetrics/` | Metrics store + built-in Prometheus scraper. Edit `vmetrics/promscrape.yml` to add scrape jobs. Targets page: `http://localhost:28428/targets`. |
| `vlogs` | `vlogs/` | Log store. Push endpoint: `http://localhost:29428/insert/loki/api/v1/push` (Loki-compat). |
| `vtraces` | `vtraces/` | Trace store. OTLP endpoint: `http://localhost:21428/insert/opentelemetry/v1/traces`. |
| `vector` | `vector/` | Log collector. Tails `yai-*` container logs and ships to vlogs. Prometheus metrics on `:9598`. |
| `node-exporter` | `node-exporter/` | Node Exporter. Host OS metrics scraped by vmetrics as `node_exporters`. |
| `grafana` | `grafana/` | UI only. Datasources use container-name DNS on `yai-infra` (e.g. `http://yai-vmetrics:8428`). |

Wire OTLP traces from LiteLLM and Langfuse to
`http://host.docker.internal:21428/insert/opentelemetry/v1/traces`, and ship
logs via the Loki-compatible push API at
`http://host.docker.internal:29428/insert/loki/api/v1/push`.

## Rules for agents

- **Never commit `.env` files containing real secrets.** Placeholders
  (`change_me`) are fine and tracked; replace locally before starting.
- **Never overwrite `.env` files** when editing or regenerating compose files
  — only touch `docker-compose.yml`. When adding a new variable, append it to
  the `.env` with a comment; do not reorganise existing entries.
- **Run `./yai.sh init all`** after any structural change (new volumes, new
  services) to ensure data directories exist.
- **Prefer editing existing files** over creating new ones.
- **Do not add stacks beyond those defined here** without explicit user
  instruction. The matrix in this file is the source of truth — when a new
  service is added, update both the table above and the `SERVICES` array in
  `yai.sh`.
- **`data/` directories are runtime state** — never delete them while the
  service is running; never commit them.
- **No named Docker volumes** — all bind mounts use direct `./data/...` paths
  in the service `volumes:` list. Never add a top-level `volumes:` stanza with
  `driver_opts` bind mounts; they resolve to absolute paths at volume-creation
  time and break when the repo moves or is cloned to a different path.
- **Image pinning**: every `docker-compose.yml` reads its image tag from an
  env var (`<SERVICE>_VERSION`) with a hard-pinned default. Update the
  default, not just the env file, so a fresh checkout uses the same version.
- **Port collisions**: every yai service has a unique host port. The current
  allocation lives in the table above; preserve it when adding new services.
  Note `27001` is taken by Traefik's API; `27000` and `27002` are free since
  agent-browser moved to a host skill.
- **Postgres ownership**: only `postgres/` is the shared instance. `n8n`,
  `windmill`, `firecrawl`, and `langfuse` each embed their own DB on an
  internal-only network. Do not "consolidate" these onto the shared
  `postgres/` — every upstream project ships migrations expecting a private
  DB.
- **MinIO ownership**: `minio/` is the general-purpose store. `langfuse/`
  embeds its own MinIO for trace payloads — leave it alone.

## Environment — `env.sh`

URLs, tokens, and connection strings for every service live in:

- **`env.sh`** at the repo root — `source ./env.sh` exports
  `YAI_<SVC>_URL`, API tokens, and Postgres credentials.
- **`.claude/skills/yai/SKILL.md`** — stack overview, full URL table,
  canonical service-name table, service groups, operating rules.
- **`.claude/skills/<tool>/SKILL.md`** — one skill per backend
  (`vlogs`, `vmetrics`, `vtraces`, `grafana`, `litellm`, `langfuse`).
  Skills auto-load when the relevant tech is in scope.

## Slash commands (`/yai:*`)

Three namespaces, all under `/yai:`:

- **`/yai:service:*` — docker-compose level.** Direct `./yai.sh`
  invocations. Use for container-level operations.
  - `/yai:service:logs <service>` — tail + interpret docker logs
  - `/yai:service:ps [service|all]` — container status across the stack
  - `/yai:service:doctor` — run `./yai.sh doctor` and interpret findings
  - `/yai:service:restart <service>` — restart one service (confirms first)

- **`/yai:infra:*` — atomic observability reads.** One signal, one
  service, one read. Token-light. Auto-loads the relevant backend skill.
  - `/yai:infra:logs <service> [<prompt|window=6h>...]`
  - `/yai:infra:metrics <service> [<prompt|window=24h>...]`
  - `/yai:infra:traces <service> [<prompt|lookback=1h>...]`
  - `/yai:infra:http <service> <path> [METHOD] [<prompt>...]`

- **`/yai:sre:*` — composite triage.** Multi-service fan-out via
  parallel subagents, then synthesis.
  - `/yai:sre:logs [service|--all|--obs|--llm|--browser|--workflows|--data] [window=6h]`

- **`/yai:grafana:*` — Grafana tooling.**
  - `/yai:grafana:debug <dashboard UID | title> [symptom]`

### Conventions for new slash commands

1. **One file = one entrypoint.** Place under
   `.claude/commands/yai/<namespace>/<name>.md`. Subdirectories become
   colon-separated namespaces.
2. **Frontmatter is mandatory:** `description`, `argument-hint`,
   `allowed-tools`. Keep `allowed-tools` minimal (`Read, Bash` covers
   most read-only triage).
3. **Persona.** Lead the body with one tight paragraph describing the
   role and goal.
4. **Don't restate service URLs or stack details.** Refer to the `yai`
   skill or the service-specific skill — they carry the syntax + recipes.
5. **Atomic = one signal, one target.** Don't add "also pull metrics"
   to a logs command. Compose at the `sre:` layer.
6. **Composite commands fan out via parallel subagents.** Single
   message, multiple `Agent` calls. Synthesise — don't concatenate.
7. **Output format is part of the contract.** Each command spells out
   the report shape its caller expects.
8. **Read-only by default.** State-changing actions (restarts, config
   changes, secret rotation) are *surfaced* as recommendations and
   require explicit user authorisation.

## Versions & upstream docs

Each `<service>/AGENTS.md` lists the canonical upstream docs and release-page
URLs. Use those when bumping versions; verify against the upstream
release notes (especially for breaking changes — Langfuse v2 → v3 was a
total architectural rewrite, and LiteLLM had a supply-chain incident in
March 2026).
