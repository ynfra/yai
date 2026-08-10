---
name: yai
description: yai stack meta — service URLs, env.sh credentials, canonical service-name table, port map, service groups. Auto-load when interacting with any yai service (Grafana, VictoriaMetrics, VictoriaLogs, VictoriaTraces, LiteLLM, Langfuse, n8n, Windmill, Qdrant, MinIO, Postgres, Browserless, Firecrawl) or when the user mentions yai / the stack / a service by name.
when_to_use: Load for any question involving the yai stack, service health, URLs, credentials, CLI operations, or any time you need to know what port a service runs on, how to address it from another container, or which yai.sh command to use. Also load when the user mentions any yai service by name (Grafana, n8n, LiteLLM, etc.) without a more specific context.
allowed-tools: Bash(source ./env.sh) Bash(./yai.sh *)
---

# yai stack

Self-hosted AI infrastructure. Every service is an isolated
docker-compose project under its own folder, managed by `./yai.sh`. All
data is bind-mounted to `./<service>/data/`.

## URLs (from `env.sh`)

| Service | URL env var | Host port |
|---------|------------|-----------|
| Grafana | `YAI_GRAFANA_URL` | 22000 |
| VictoriaMetrics | `YAI_VMETRICS_URL` | 28428 |
| VictoriaLogs | `YAI_VLOGS_URL` | 29428 |
| VictoriaTraces | `YAI_VTRACES_URL` | 21428 |
| LiteLLM | `YAI_LITELLM_URL` | 24000 |
| Langfuse | `YAI_LANGFUSE_URL` | 23000 |
| n8n | `YAI_N8N_URL` | 26002 |
| Windmill | `YAI_WINDMILL_URL` | 28000 |
| Qdrant | `YAI_QDRANT_URL` | 26000 |
| MinIO S3 | `YAI_MINIO_URL` | 25000 |
| MinIO console | `YAI_MINIO_CONSOLE_URL` | 25001 |
| Postgres | `YAI_POSTGRES_HOST:YAI_POSTGRES_PORT` | 25432 |
| Browserless | `YAI_BROWSERLESS_URL` | 26003 |
| Firecrawl | `YAI_FIRECRAWL_URL` | 21000 |

## Credentials

```sh
source ./env.sh
```

Exposes all URLs above, plus `YAI_GRAFANA_TOKEN`, `YAI_LITELLM_MASTER_KEY`,
`YAI_LANGFUSE_PUBLIC_KEY`, `YAI_LANGFUSE_SECRET_KEY`, `YAI_POSTGRES_DSN`,
`PGPASSWORD`.

All tokens in `env.sh` must be set to real values before using the corresponding service's API.

Do not paste tokens into external systems or logs.

## Canonical service table

When a command takes `<service>`, resolve through this table:

| key | vmetrics `job` | vlogs `service_name` | vtraces service | docker compose project |
|-----|---------------|---------------------|----------------|----------------------|
| `grafana` | — | grafana | — | grafana/ |
| `vmetrics` | victoria-metrics | victoria-metrics | — | vmetrics/ |
| `vlogs` | victoria-logs | victoria-logs | — | vlogs/ |
| `vtraces` | — | victoria-traces | — | vtraces/ |
| `litellm` | litellm | litellm | litellm | litellm/ |
| `langfuse` | langfuse-web | langfuse | langfuse | langfuse/ |
| `n8n` | n8n | n8n | n8n | n8n/ |
| `windmill` | windmill | windmill | windmill | windmill/ |
| `qdrant` | qdrant | qdrant | — | qdrant/ |
| `minio` | minio | minio | — | minio/ |
| `postgres` | — | postgres | — | postgres/ |
| `browserless` | — | browserless | — | browserless/ |
| `firecrawl` | — | firecrawl | — | firecrawl/ |

Notes:
- vmetrics job names come from `vmetrics/promscrape.yml` (built-in scraper; no separate vmagent).
- vlogs `service_name` depends on what label each service ships in its
  Loki push — treat these as conventions; discover real field values via
  the vlogs skill's field-discovery recipe.
- LiteLLM, Langfuse, n8n, and Windmill can emit OTLP traces to
  VictoriaTraces (`YAI_VTRACES_URL/insert/opentelemetry/v1/traces`).

## Service groups (used by `/yai:sre:*` fan-out)

- `--obs` → grafana, vmetrics, vlogs, vtraces
- `--llm` → litellm, langfuse
- `--browser` → browserless, firecrawl
- `--workflows` → n8n, windmill
- `--data` → postgres, minio, qdrant
- `--all` → union of all groups

## Tech split per signal

| Signal | Backend | Query language | Skill |
|--------|---------|---------------|-------|
| Logs | VictoriaLogs | LogsQL (not LogQL) | `vlogs` |
| Metrics | VictoriaMetrics | PromQL/MetricsQL | `vmetrics` |
| Traces | VictoriaTraces | Jaeger HTTP API | `vtraces` |
| LLM gateway | LiteLLM | REST API | `litellm` |
| LLM traces/evals | Langfuse | REST API | `langfuse` |
| Docker containers | `./yai.sh` | Bash | — |

## Management CLI

```sh
./yai.sh stack start         # bring up all services
./yai.sh service n8n logs    # tail logs for one service
./yai.sh ps all              # container status across the stack
./yai.sh doctor              # toolchain + secrets + compose check
./yai.sh service n8n restart # restart one service
```

## Operating rules

- **Read-first.** Default to read-only API calls. Never restart, mutate
  data, or change configs without explicit user approval.
- **Cite sources.** Include the endpoint path, panel title, or raw query
  so the user can reproduce the finding.
- **No data exfiltration.** Don't paste metrics, logs, tokens, or LLM
  call payloads into external systems unless explicitly authorised.
- **Source env.sh first.** All credentials and URLs are in `env.sh`.
  Never hardcode ports or credentials in commands.

## Slash command namespaces

Three namespaces under `/yai:`:

- `/yai:service:*` — docker-compose level: logs, ps, doctor, restart.
  Direct `./yai.sh` invocations.
- `/yai:infra:*` — atomic observability reads: one signal, one service.
  Token-light. Auto-loads the relevant backend skill.
- `/yai:sre:*` — composite triage: multi-service fan-out with subagent
  parallelism and synthesis.
- `/yai:grafana:*` — Grafana-specific tooling (debug, screenshots).

See `AGENTS.md` for the full convention.
