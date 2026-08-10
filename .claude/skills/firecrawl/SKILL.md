---
name: firecrawl
description: Firecrawl web crawling & scraping API on the yai stack — scrape, crawl, extract endpoints, job status, concurrency knobs, proxy config. Auto-load on Firecrawl, web scrape, crawl, extract, markdown, web content questions.
when_to_use: Load when the user wants to scrape a website, crawl a domain, extract structured data from web pages, or convert web content to markdown. Also load when debugging Firecrawl job status or configuring concurrency and proxy settings.
allowed-tools: Bash(curl *)
---

# Firecrawl

Self-hosted web scraping and crawling API. Renders pages through headless Chromium,
returns markdown and/or structured JSON. URL: `YAI_FIRECRAWL_URL` (port 21000).

> **No Fire-engine (self-hosted limitation).** Sites with aggressive bot protection
> (Cloudflare Turnstile, PerimeterX, DataDome) may fail here but succeed on the
> hosted `api.firecrawl.dev`. Configure `PROXY_SERVER` in `.env` for a residential
> proxy if needed.
>
> For agent-driven interactive browsing, use `agent-browser` instead — Firecrawl is
> for crawl pipelines and bulk scrape.

## Health check

```sh
source ./env.sh
curl -s "$YAI_FIRECRAWL_URL/v1/health" | jq
```

## Scrape a single URL

```sh
# Returns markdown + metadata
curl -s -X POST "$YAI_FIRECRAWL_URL/v1/scrape" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}' | jq '{markdown: .data.markdown, title: .data.metadata.title}'

# Request only specific formats
curl -s -X POST "$YAI_FIRECRAWL_URL/v1/scrape" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com", "formats": ["markdown", "links"]}' | jq
```

## Crawl a site (async)

```sh
# Start crawl — returns a job ID
JOB=$(curl -s -X POST "$YAI_FIRECRAWL_URL/v1/crawl" \
  -H 'Content-Type: application/json' \
  -d '{
    "url": "https://docs.example.com",
    "limit": 50,
    "scrapeOptions": {"formats": ["markdown"]}
  }' | jq -r '.id')
echo "Job: $JOB"

# Poll status
curl -s "$YAI_FIRECRAWL_URL/v1/crawl/$JOB" | jq '{status, completed, total}'

# Get results when done
curl -s "$YAI_FIRECRAWL_URL/v1/crawl/$JOB" | jq '.data[].markdown' | head -20
```

## LLM extraction (structured output)

Requires `OPENAI_API_KEY` / `OPENAI_BASE_URL` in `.env`. Point at LiteLLM:
```
OPENAI_BASE_URL=http://host.docker.internal:24000/v1
OPENAI_API_KEY=<litellm-master-key>
MODEL_NAME=gpt-4o
```

```sh
curl -s -X POST "$YAI_FIRECRAWL_URL/v1/scrape" \
  -H 'Content-Type: application/json' \
  -d '{
    "url": "https://example.com/product",
    "formats": ["extract"],
    "extract": {
      "schema": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "price": {"type": "number"}
        }
      }
    }
  }' | jq '.data.extract'
```

## Queue admin UI

```
http://localhost:21000/admin/<BULL_AUTH_KEY>/queues
```
`BULL_AUTH_KEY` is in `firecrawl/.env`. Treat the URL as a credential.

## Concurrency knobs (`.env`)

| Variable | Default | Effect |
|----------|---------|--------|
| `NUM_WORKERS_PER_QUEUE` | 2 | Worker threads per Bull queue |
| `MAX_CONCURRENT_JOBS` | 5 | Total parallel jobs |
| `CRAWL_CONCURRENT_REQUESTS` | 5 | Parallel page requests per crawl |
| `BROWSER_POOL_SIZE` | 2 | Playwright Chromium instances |

Playwright + Chromium is memory-hungry. Lower these values on a constrained host before raising worker counts.

## Operational notes

- **First start** takes ~10–15 s — RabbitMQ healthcheck blocks the API until the broker is accepting connections.
- **No shared Postgres.** The `nuq-postgres` image has `pg_cron` baked in; do not substitute the shared `yai/postgres` instance.
- `POSTGRES_USER` / `POSTGRES_DB` must stay `postgres` — hardcoded in `pg_cron` bootstrap.
- `USE_DB_AUTHENTICATION=false` is required for self-hosted (disables the hosted Supabase auth path).
