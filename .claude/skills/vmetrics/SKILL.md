---
name: vmetrics
description: VictoriaMetrics single-node on the yai stack — PromQL/MetricsQL, scrape job names (from vmetrics/promscrape.yml), query gotchas, HTTP API recipes. Auto-load on VictoriaMetrics, vmetrics, PromQL, MetricsQL, metric query, recording rule, scrape target questions.
when_to_use: Load when the user asks about metrics, dashboards backed by VictoriaMetrics, PromQL or MetricsQL syntax, scrape job health, metric prefixes for any yai service, or how to add a new scrape target to the stack.
---

# VictoriaMetrics

Single-node binary with **built-in Prometheus scraper**. URL in env: `YAI_VMETRICS_URL` (port 28428).
There is no separate vmagent — scrape config lives in `vmetrics/promscrape.yml`.

## Scrape jobs (from `vmetrics/promscrape.yml`)

| job_name | target | metrics path |
|----------|--------|-------------|
| `vmetrics_metrics` | localhost:8428 | /metrics |
| `vlogs_metrics` | yai-vlogs:9428 | /metrics |
| `vtraces_metrics` | yai-vtraces:10428 | /metrics |
| `postgres` | yai-pg-exporter:9630 | /metrics |
| `grafana_metrics` | yai-grafana:3000 | /metrics |
| `vector_metrics` | yai-vector:9598 | /metrics |
| `node_exporters` | yai-node-exporter:9100 | /metrics |
| `traefik_metrics` | yai-traefik:8080 | /metrics |
| `qdrant` | host.docker.internal:26000 | /metrics |
| `litellm` | host.docker.internal:24000 | /metrics/ |
| `langfuse-web` | host.docker.internal:23000 | /api/public/metrics |
| `n8n` | host.docker.internal:26002 | /metrics |
| `minio_metrics` | host.docker.internal:25000 | /minio/v2/metrics/cluster |
| `minio_bucket_metrics` | host.docker.internal:25000 | /minio/v2/metrics/bucket |

Add new jobs to `vmetrics/promscrape.yml`, then `./yai.sh restart vmetrics`.

## HTTP API quick-ref

```sh
source ./env.sh

# Instant query
curl -sG "$YAI_VMETRICS_URL/api/v1/query" \
  --data-urlencode 'query=up'

# Range query
curl -sG "$YAI_VMETRICS_URL/api/v1/query_range" \
  --data-urlencode 'query=rate(litellm_request_duration_seconds_count[5m])' \
  --data-urlencode "start=$(date -u -d '1 hour ago' +%s)" \
  --data-urlencode "end=$(date -u +%s)" \
  --data-urlencode 'step=30s'

# All metric names
curl -s "$YAI_VMETRICS_URL/api/v1/label/__name__/values" | jq -r '.data[]'

# Jobs that are up
curl -sG "$YAI_VMETRICS_URL/api/v1/query" \
  --data-urlencode 'query=up' | jq -r '.data.result[] | "\(.metric.job): \(.value[1])"'

# Scrape targets health (built-in targets page)
open "$YAI_VMETRICS_URL/targets"
```

## Query gotchas

- **Verify metric names before querying.** Use
  `/api/v1/label/__name__/values` and grep for the prefix — metric names
  vary by exporter version.
- **Empty-result fallback.** Use `<expr> or vector(0)` to render 0
  instead of "No data" when a metric may legitimately be absent.
- **Scrape interval is 30s** (global default in `vmagent.yml`). Use
  `rate(...[1m])` or longer windows for rate calculations.
- **Label matcher on a binop is silent.** Distribute matchers to both
  sides of a binary operation:
  ```promql
  # Wrong — {job="litellm"} on the outside doesn't filter the binop
  (metric_a / metric_b){job="litellm"}
  # Right
  metric_a{job="litellm"} / metric_b{job="litellm"}
  ```

## Useful metric prefixes by service

| Service | Metric prefix | Key signals |
|---------|--------------|-------------|
| LiteLLM | `litellm_*` | request count, latency, errors by model |
| n8n | `n8n_*` | workflow executions, errors |
| Windmill | `windmill_*` | job duration, queue depth |
| Qdrant | `app_*` (qdrant) | collections, vectors indexed |
| MinIO | `minio_*` | requests, errors, storage usage |
| VictoriaMetrics | `vm_*` | ingestion rate, storage, query latency |
| VictoriaLogs | `vlogs_*` | log ingestion rate, storage |
| vector | `vector_*` | log ship lag, event processing rate |
