# Audit prompts

One paste-ready audit prompt per service group in the yai stack. Each
prompt auto-loads the relevant skill on its keywords; run them
individually, or fan out in parallel via `/yai:sre:logs --all` when you
want a stack-wide pass in one go.

`source ./env.sh` first.

---

## Stack-wide — full health sweep

```
Full yai stack health audit. Source ./env.sh.

Run /yai:service:doctor — interpret every FAIL and WARN finding.
Then fan out /yai:infra:logs for each service group in parallel:
  - --obs:       grafana, vmetrics, vlogs, vtraces, vmagent
  - --llm:       litellm, langfuse
  - --workflows: n8n, windmill
  - --data:      postgres, minio, qdrant
  - --browser:   browserless, firecrawl

For each service: container state, log volume last 6h, error/warn count,
top 3 patterns classified (REAL / STARTUP-NOISE / MISCONFIGURED / BENIGN).
Cross-service synthesis: group findings by root cause, not by service.

End with GREEN / YELLOW / RED verdict and a ranked action list.
```

---

## `vlogs` — VictoriaLogs

```
Audit VictoriaLogs on the yai stack. Source ./env.sh.

- Log ingestion rate over 24h, broken down by service_name:
  curl "$YAI_VLOGS_URL/select/logsql/hits" -d 'query=*' ...
- List all service_names currently shipping logs:
  curl "$YAI_VLOGS_URL/select/logsql/streams" -d 'query=*'
- Any service from the yai skill's service table with 0 hits in 24h
  — log shipping not wired vs. genuinely silent?
- Storage size and growth: /metrics endpoint (vm_data_size_bytes on VictoriaLogs).
- Query latency p50/p99 (vlogs_request_duration_seconds).
- Field discovery on top 5 service_names — sanity-check that parsed
  fields are present (litellm → model/status, n8n → execution_id).

Verdict + ranked actions.
```

---

## `vmetrics` — VictoriaMetrics

```
Audit VictoriaMetrics on the yai stack. Source ./env.sh.

- up{} per scrape job — compare against job list in grafana/vmagent.yml.
  Flag any job that is 0 or flapping.
- vmagent targets page: curl "$YAI_VMAGENT_URL/api/v1/targets" | jq
  — any targets in "down" state.
- Active series count + ingestion rate (vm_rows_inserted_total rate).
- Storage usage (vm_data_size_bytes); predict_linear 30d fill.
- Slow queries: vm_slow_queries_total or logs from victoria-metrics
  service in vlogs.
- Top cardinality metrics: curl "$YAI_VMETRICS_URL/api/v1/status/tsdb"
  — any unexpected cardinality explosion (e.g. from LiteLLM tracing labels).

Verdict + ranked actions.
```

---

## `litellm` — LLM gateway

```
Audit LiteLLM on the yai stack. Source ./env.sh.

- Health: curl "$YAI_LITELLM_URL/health" (checks all configured models).
- Models configured: curl -H "Authorization: Bearer $YAI_LITELLM_MASTER_KEY"
  "$YAI_LITELLM_URL/v1/models" — list all model names.
- Request rate and error rate over 24h (litellm_* metrics in VictoriaMetrics).
- Spend last 24h: top 5 models by cost and by token count.
- Last 20 failed requests: curl "$YAI_LITELLM_URL/spend/logs?limit=100" |
  jq '[.[] | select(.status_code != "200")]' — root cause each failure.
- Postgres DB connection: check litellm logs for DB errors.
- config.yml vs DB-stored models: any drift (model in UI but not in config,
  or vice versa)?

Verdict + ranked actions tied to file paths (litellm/config.yml, litellm/.env).
```

---

## `langfuse` — LLM observability

```
Audit Langfuse on the yai stack. Source ./env.sh.

- Health: curl "$YAI_LANGFUSE_URL/api/public/health"
- Traces volume last 24h: curl -u "$YAI_LANGFUSE_PUBLIC_KEY:$YAI_LANGFUSE_SECRET_KEY"
  "$YAI_LANGFUSE_URL/api/public/traces?limit=1&page=1" — count total.
- Trace error rate: traces with error=true or status!=success.
- Top models by latency and token count (from observations endpoint).
- vmagent scrape: up{job="langfuse-web"} in VictoriaMetrics.
- Logs in vlogs (service_name=langfuse) over 24h — error patterns.
- Clickhouse + Redis health: check langfuse worker logs for DB errors.

Verdict + ranked actions.
```

---

## `grafana` — dashboards & datasources

```
Audit Grafana on the yai stack. Source ./env.sh.

- Health: curl "$YAI_GRAFANA_URL/api/health"
- All datasources: curl -H "Authorization: Bearer $YAI_GRAFANA_TOKEN"
  "$YAI_GRAFANA_URL/api/datasources" — list uid, name, type, url.
  Probe each: for VictoriaMetrics, try up{}. For VictoriaLogs, try a
  simple hits query. For VictoriaTraces, try /api/services.
- All dashboards: curl ... /api/search?type=dash-db — title, uid, folder.
- vmagent targets page: is grafana itself being scraped? (it may not
  expose /metrics by default — note if absent)
- Grafana logs (service_name=grafana in vlogs): any datasource plugin
  errors or dashboard load failures.
- Plugin status: GF_INSTALL_PLUGINS — are Victoria* plugins installed?
  curl "$YAI_GRAFANA_URL/api/plugins" | jq '.[].id' | grep victoria

Per-datasource verdict, then summary.
```

---

## `n8n` — workflow automation

```
Audit n8n on the yai stack. Source ./env.sh.

- Container health: ./yai.sh ps n8n — all containers (server, worker,
  webhook, redis, postgres) running?
- Recent workflow executions: curl -H "X-N8N-API-KEY: <key>"
  "$YAI_N8N_URL/api/v1/executions?limit=20" — status distribution
  (success / error / waiting).
- Error executions last 24h: filter to status=error, top 5 workflows
  by error count.
- Queue depth (if queue mode): Redis queue length from n8n logs or
  n8n metrics endpoint.
- Metrics: up{job="n8n"} in VictoriaMetrics.
- Logs (service_name=n8n in vlogs) over 24h — top error patterns.

Verdict + ranked actions.
```

---

## `windmill` — workflow & script engine

```
Audit Windmill on the yai stack. Source ./env.sh.

- Container health: ./yai.sh ps windmill — server, workers, native
  worker, postgres all running?
- Metrics: up{job="windmill"} in VictoriaMetrics. Worker utilisation,
  job queue depth (windmill_* metrics).
- Recent job failures: Windmill UI at "$YAI_WINDMILL_URL" → Jobs →
  filter by status=failed. Or via REST API if wired.
- Logs (service_name=windmill in vlogs) over 24h — top error patterns.
- Postgres: Windmill uses its own embedded postgres; check for
  connection errors in windmill logs.

Verdict + ranked actions.
```

---

## `qdrant` — vector database

```
Audit Qdrant on the yai stack. Source ./env.sh.

- Health: curl "$YAI_QDRANT_URL/healthz"
- Collections: curl "$YAI_QDRANT_URL/collections" | jq
  For each: vector count, index status, segment count.
- Metrics: up{job="qdrant"} in VictoriaMetrics. Key signals:
  app_requests_total rate, app_grpc_responses_fail_total rate.
- Telemetry: curl "$YAI_QDRANT_URL/telemetry" | jq
  — latency percentiles per collection.
- Disk usage: ./data/qdrant/ size on host.

Verdict + ranked actions.
```

---

## Cross-cutting fan-out

When you want a full stack pass instead of one-at-a-time, wrap several
of these into a single Agent fan-out — e.g. *"audit litellm + langfuse +
vmetrics in parallel and synthesise"* — and the orchestrator spawns one
subagent per service, each loading just the relevant context.
