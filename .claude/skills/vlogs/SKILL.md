---
name: vlogs
description: VictoriaLogs (LogsQL, not LogQL) on the yai stack — stream fields, field discovery, HTTP API recipes, bash helpers, Grafana panel patterns. Auto-load on VictoriaLogs, vlogs, LogsQL, log query, service_name filter, log panel, log stream questions.
when_to_use: Load when the user asks about log queries, error patterns in a specific service, log volume stats, stream field discovery, or wants to create a Grafana log panel. Also load for any question about VictoriaLogs, LogsQL syntax, the Loki push API, or debugging why logs are missing from vlogs.
allowed-tools: Bash(curl *)
---

# VictoriaLogs

Query language is **LogsQL**, not LogQL. URL in env: `YAI_VLOGS_URL`
(port 29428). Datasource type in Grafana: `victoriametrics-logs-datasource`.

## Log shipping

Services push logs to the Loki-compatible push API:
```
http://localhost:29428/insert/loki/api/v1/push
# From inside another compose network:
http://host.docker.internal:29428/insert/loki/api/v1/push
```

Each push includes a `service_name` label (and optionally `host`, `cluster`).
The `service_name` values in the canonical service table are conventions —
verify with field discovery below since each service controls its own labels.

## Field discovery

```sh
source ./env.sh
curl -s "$YAI_VLOGS_URL/select/logsql/field_names" -d 'query=*'
# Filter to one service:
curl -s "$YAI_VLOGS_URL/select/logsql/field_names" \
  -d 'query={service_name="litellm"}'
```

Run this before writing queries against an unfamiliar source.

## HTTP API endpoints

| Endpoint | Purpose |
|----------|---------|
| `/select/logsql/streams` | Label/stream discovery |
| `/select/logsql/field_names` | All fields in the query window |
| `/select/logsql/hits` | Volume over time (`step=` for bucket size) |
| `/select/logsql/query` | Raw query — streams results |

All take `query=<logsql>` and optionally `start=<RFC3339>` (defaults to now).

## Bash recipe

```sh
source ./env.sh
START=$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)

hits() {
  curl -sf "$YAI_VLOGS_URL/select/logsql/hits" \
    --data-urlencode "query=$1" \
    --data-urlencode "start=$START" \
    --data-urlencode "step=${2:-6h}" \
    | jq -r '.hits[0].total // 0'
}

sample() {
  curl -sf "$YAI_VLOGS_URL/select/logsql/query" \
    --data-urlencode "query=$1" \
    --data-urlencode "start=$START" \
    --data-urlencode "limit=20"
}
```

## LogsQL pipes worth remembering

```
# Volume + severity
{service_name="litellm"} ERROR | stats by (_msg) count() as c | sort by (c desc) | limit 10

# Extract a field and count distribution
{service_name="litellm"} | extract "level=<lvl> " | stats by (lvl) count()

# Sample recent errors
{service_name="n8n"} (ERROR OR FATAL) | fields _time, _msg | limit 20

# LiteLLM: slow requests
{service_name="litellm"} | fields _time, _msg | filter _msg:~"duration.*[0-9]{4,}"
```

Use `| limit N` early when sampling — VictoriaLogs streams results.

## Grafana panel patterns

- **Logs panel** needs a real `_msg`. After `| fields …` strips fields,
  build one with `format`:
  ```
  | format "<status> <method> <path> dur=<duration>ms" as _msg
  | fields _time, _msg, status, method
  ```
  Without it, rows render as `{key=val, …}` blobs.
- **`queryType` is mandatory on every LogsQL target.** Pick:
  - `stats` — instant scalar/table queries (`| stats count() as count`)
  - `statsRange` — timeseries panels (`| stats by (_time:1m) count() as count`)
  - `range` — log-line panels and live-tail
  - `instant` — table panels backed by `stats by (...)`
  Also alias every aggregation: `count() as count`, not bare `count()`.
- **Multi-select variables** in regex need `:pipe`:
  `service_name:~"${service:pipe}"`. Bare `$var` joins with `,`.
