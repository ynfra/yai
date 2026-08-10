---
description: Query VictoriaTraces (Jaeger) for one yai service and analyse
argument-hint: <service> [<analysis prompt | lookback=1h>...]
allowed-tools: Read, Bash
---

Act as a senior observability engineer on the yai AI stack. Goal: pull
recent traces for one service from VictoriaTraces, characterise latency
distribution and error spans, and answer the user's question.

User input: $ARGUMENTS

## Inputs

- **`<service>`** — Jaeger service name. Use the `yai` skill's service
  table to map canonical key → vtraces service name.
- **Analysis prompt** — free-form (*"find slowest operations"*, *"any
  error spans"*, *"correlate to LLM errors"*).
- **`lookback=<dur>`** — optional; default `1h`.

Services known to emit traces: `litellm`, `langfuse`, `n8n`, `windmill`
(when wired with OTLP env vars — see `vtraces` skill).

## Workflow

1. **Bootstrap.** `source ./env.sh`. The `vtraces` skill carries the
   Jaeger HTTP API recipe.

2. **Service exists?** `GET /api/services` — if `<service>` isn't listed,
   either OTLP isn't wired up or the name doesn't match. Stop early.
   ```sh
   curl -s "$YAI_VTRACES_JAEGER_URL/api/services" | jq -r '.data[]'
   ```

3. **Operations + latency.** Pull operations, then a sample of recent
   traces:
   ```sh
   curl -s "$YAI_VTRACES_JAEGER_URL/api/services/<svc>/operations" \
     | jq -r '.data[]'
   curl -sG "$YAI_VTRACES_JAEGER_URL/api/traces" \
     --data-urlencode "service=<svc>" \
     --data-urlencode "limit=20" \
     | jq '.data[] | {traceID, duration, spans: (.spans | length)}'
   ```

4. **Classify spans.** Top by p99 duration, any with `error=true` tag.

5. **Answer the prompt.** Tie findings to trace IDs so the user can open
   them in Grafana Explore (Jaeger datasource).

## Output format

```
service: <svc>   lookback: <window>   sampled traces: <N>

Operations (top by p99):
  <op>  count=<N>  p50=<ms>  p99=<ms>  err_pct=<pct>
  ...

Notable traces:
  - traceID=<id>  duration=<ms>  spans=<N>  error=<true|false>  →  <summary>

Verdict: <one line>
```

## Don'ts

- Don't fabricate trace IDs.
- If the service isn't emitting traces, say so and point to the `vtraces`
  skill for wiring instructions.
- Read-only.
