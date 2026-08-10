---
name: vtraces
description: VictoriaTraces (OTLP ingest, Jaeger-compatible query) on the yai stack — which services emit traces, HTTP API recipes, OTLP endpoint. Auto-load on VictoriaTraces, vtraces, OTLP, trace, Jaeger, span questions.
when_to_use: Load when the user asks about distributed tracing, OTLP configuration, trace correlation, Jaeger API queries, or wants to find slow spans in a specific service. Also load when wiring LiteLLM or Langfuse to emit traces to VictoriaTraces.
allowed-tools: Bash(curl *)
---

# VictoriaTraces

OTLP ingest + Jaeger-compatible query API. URL in env: `YAI_VTRACES_URL`
(port 21428).

```
# Jaeger endpoint (for Grafana datasource and queries)
YAI_VTRACES_JAEGER_URL="${YAI_VTRACES_URL}/select/jaeger"

# OTLP ingest (from other services)
http://localhost:21428/insert/opentelemetry/v1/traces
# From inside another compose network:
http://host.docker.internal:21428/insert/opentelemetry/v1/traces
```

VictoriaTraces is still on a **v0.x** release line — read the release
notes before bumping the version in `grafana/.env`.

## Services that emit traces

Configure these env vars in each service's `.env` to ship OTLP traces:

```sh
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal:21428/insert/opentelemetry/v1/traces
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

| Service | Native OTLP support | service.name in traces |
|---------|-------------------|----------------------|
| LiteLLM | Yes (built-in) | `litellm` |
| Langfuse | Yes (worker) | `langfuse` |
| n8n | Yes (OTEL env vars) | `n8n` |
| Windmill | Yes (OTEL env vars) | `windmill` |

## Jaeger HTTP API quick-ref

```sh
source ./env.sh
BASE="$YAI_VTRACES_JAEGER_URL"

# List all services emitting traces
curl -s "$BASE/api/services" | jq -r '.data[]'

# Operations for a service
curl -s "$BASE/api/services/litellm/operations" | jq -r '.data[]'

# Recent traces for a service
curl -sG "$BASE/api/traces" \
  --data-urlencode "service=litellm" \
  --data-urlencode "limit=20" \
  | jq '.data[] | {traceID, duration, spans: (.spans | length)}'

# One trace by ID
curl -s "$BASE/api/traces/<traceID>" | jq
```

## Query notes

- VictoriaTraces accepts OTLP/HTTP and OTLP/gRPC on the same listen
  address. For gRPC use `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`.
- The Grafana datasource type is `jaeger`, pointed at `YAI_VTRACES_JAEGER_URL`.
- Don't fabricate trace IDs. If the sample returns empty, say so.
- Trace IDs can be linked in Grafana using the built-in Jaeger explore
  view — useful for correlating with metrics (Exemplar linking) or logs.

## Troubleshooting

- **No traces visible**: Confirm the OTLP endpoint is `http://host.docker.internal:21428/insert/opentelemetry/v1/traces` (not `localhost` from inside a container). Verify with `curl -s http://localhost:21428/api/v2/services`.
- **Correlating with Langfuse**: LiteLLM propagates `trace_id` via OTLP when `success_callback: ["langfuse"]` is set. The Langfuse trace ID and the vtraces span ID share a root — search by the same `trace_id` in both systems.
- **Service not appearing in Jaeger UI**: The service only appears after at least one span is received. Push a test span to confirm the pipeline works before assuming a config issue.
