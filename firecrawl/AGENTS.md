# firecrawl — self-hosted web scraping & crawling API

Firecrawl turns websites into LLM-ready data: it crawls a site, renders pages
through a headless browser, extracts content as markdown / structured JSON, and
exposes everything behind a REST API. This stack runs the open-source release
locally — no SaaS dependency.

> **Self-hosted limitations.** The OSS release does **not** include
> **Fire-engine**, Firecrawl's cloud-only IP-rotation / advanced anti-bot layer.
> Sites with aggressive bot protection (Cloudflare turnstile, PerimeterX,
> DataDome, etc.) may fail here that succeed on `api.firecrawl.dev`. Configure
> `PROXY_SERVER` in `.env` to use an external residential proxy if needed.
>
> For interactive **agent-driven browsing** (a single Playwright session driven
> by an LLM), use the `agent-browser` Claude Code skill instead — Firecrawl is
> for crawl pipelines and bulk scrape.

## Architecture

Multi-container stack, all on an internal `backend` bridge network (no Traefik
/ proxy network — only the API port is exposed to the host):

| Container | Role |
|-----------|------|
| `yai-firecrawl-api` | REST API + workers; orchestrates jobs |
| `yai-firecrawl-playwright` | Headless Chromium microservice (scrapes pages) |
| `yai-firecrawl-redis` | BullMQ queue + rate-limit store |
| `yai-firecrawl-rabbitmq` | NUQ job queue (newer queue subsystem) |
| `yai-firecrawl-postgres` | `nuq-postgres` — Postgres with `pg_cron` for scheduled jobs |

The API container both serves HTTP and runs the in-process workers
(`node dist/src/harness.js --start-docker`).

## Images

| Service | Image | Tag |
|---------|-------|-----|
| api | `ghcr.io/firecrawl/firecrawl` | `latest` |
| playwright-service | `ghcr.io/firecrawl/playwright-service` | `latest` |
| nuq-postgres | `ghcr.io/firecrawl/nuq-postgres` | `latest` (no version tags published) |
| redis | `redis` | `7-alpine` |
| rabbitmq | `rabbitmq` | `3-management` |

**Pinning policy.** `firecrawl` and `playwright-service` should be bumped in
lockstep — they share Playwright service contract expectations. Firecrawl does
not publish versioned tags on GHCR; `:latest` is the only available tag.
The running version as of 2026-05-15 corresponds to v2.10 (release notes:
<https://github.com/firecrawl/firecrawl/releases>). Override via
`FIRECRAWL_IMAGE` / `PLAYWRIGHT_IMAGE` in `.env.local` if needed.

## Ports

| Host | Container | Purpose |
|------|-----------|---------|
| 21000 | 3002 | Firecrawl REST API + queue admin UI |

All other containers (Redis, RabbitMQ, Postgres, Playwright) are reachable only
on the internal `backend` network — they are not exposed to the host.

## Data layout

```
./data/
├── redis/        # Redis AOF + RDB snapshots
├── rabbitmq/     # RabbitMQ Mnesia + message store
└── postgres/     # nuq-postgres data dir (pg_cron schedules live here)
```

All three are bind-mounted via named volumes with `driver_opts: bind`.
`yai.sh ensure_data_dirs firecrawl` creates these directories on
`init` / `start`; **do not rename them** — the paths are referenced by both the
compose file and `yai.sh`.

## First-time setup

```bash
# 1. Rotate secrets in .env — at minimum:
#      BULL_AUTH_KEY      (anyone who knows it can reach the queue admin UI)
#      POSTGRES_PASSWORD  (nuq-postgres credential)
$EDITOR .env

# 2. Init data dirs + warn on placeholder secrets
../yai.sh init firecrawl

# 3. Start the stack
../yai.sh start firecrawl

# 4. Sanity check
curl -s http://localhost:21000/v1/health | jq .

# 5. First scrape
curl -X POST http://localhost:21000/v1/scrape \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com"}'
```

### Queue admin UI

After start, the BullMQ queue dashboard is reachable at:

```
http://<host>:21000/admin/<BULL_AUTH_KEY>/queues
```

Replace `<BULL_AUTH_KEY>` with the value from your `.env`. Treat that URL as a
credential — anyone who can reach it can drain or replay jobs.

## Environment variables

The full set lives in `.env`; the load-bearing ones are:

- `PORT` — host port for the API (default `21000`); `INTERNAL_PORT=3002`
  is the container side.
- `BULL_AUTH_KEY` — gates the queue admin UI.
- `POSTGRES_USER` / `POSTGRES_DB` — **must stay `postgres`**; the `nuq-postgres`
  image initialises `pg_cron` against `cron.database_name = "postgres"`.
- `USE_DB_AUTHENTICATION=false` — disables the Supabase auth path that the
  hosted version uses; required for self-hosted.
- `NUM_WORKERS_PER_QUEUE`, `CRAWL_CONCURRENT_REQUESTS`, `MAX_CONCURRENT_JOBS`,
  `BROWSER_POOL_SIZE` — concurrency knobs. The defaults assume a modestly
  sized host; raise carefully — Playwright is memory-hungry.
- LLM extraction (optional): `OPENAI_API_KEY`, `OPENAI_BASE_URL`, `MODEL_NAME`,
  `MODEL_EMBEDDING_NAME` — point at OpenRouter / OpenAI / any compatible
  endpoint. No local model server (this host has no GPU).
- Outbound scraping proxy: `PROXY_SERVER`, `PROXY_USERNAME`, `PROXY_PASSWORD`,
  `BLOCK_MEDIA`.
- SearXNG search: `SEARXNG_ENDPOINT`, `SEARXNG_ENGINES`, `SEARXNG_CATEGORIES`.
- `SELF_HOSTED_WEBHOOK_URL` — webhook target for crawl events.

## Operational notes

- **No external Postgres reuse.** The `nuq-postgres` image is a specialised
  build with `pg_cron` pre-installed and bootstrap migrations baked in. Do
  **not** point Firecrawl at the shared `yai/postgres` instance.
- **RabbitMQ healthcheck** blocks the API from starting until the broker is
  accepting connections — first start takes ~10-15 s.
- **Resource usage.** Playwright + Chromium can use multi-GB of RAM under
  parallel load. If the host is constrained, lower `BROWSER_POOL_SIZE` and
  `CRAWL_CONCURRENT_REQUESTS` before raising worker counts.
- **No Fire-engine.** See the note at the top — if you need cloud-grade
  anti-bot evasion, either configure a residential proxy via `PROXY_SERVER` or
  fall back to the hosted Firecrawl API.

## Docs & references

- Official docs: <https://docs.firecrawl.dev/>
- Source: <https://github.com/firecrawl/firecrawl>
- Self-hosting guide: <https://github.com/firecrawl/firecrawl/blob/main/SELF_HOST.md>
- Releases (v2.10 is latest stable as of 2026-05-15):
  <https://github.com/firecrawl/firecrawl/releases>
- nuq-postgres image: <https://github.com/firecrawl/firecrawl/pkgs/container/nuq-postgres>
- API reference: <https://docs.firecrawl.dev/api-reference/introduction>
