---
description: Query VictoriaMetrics for one yai service and analyse
argument-hint: <service> [<analysis prompt | window=24h>...]
allowed-tools: Read, Bash
---

Act as a senior SRE on the yai AI stack. Goal: pull metrics from
VictoriaMetrics for one service, detect anomalies, and answer the user's
question. Be precise — quote ranges and rates from real data.

User input: $ARGUMENTS

## Inputs

- **`<service>`** — canonical service key. Resolve to the right `job=`
  label using the `yai` skill's service table and `vmetrics` skill's
  scrape job list.
- **Analysis prompt** — free-form (*"is it saturated"*, *"detect
  anomalies in 24h"*, *"request rate and latency"*).
- **`window=<dur>`** — optional; default `24h`.

If the user only typed `<service>`, run: scrape health, saturation, error
rate, top contributors.

## Workflow

1. **Bootstrap.** `source ./env.sh`. The `vmetrics` skill carries the
   scrape job names, PromQL gotchas, and HTTP API recipe.

2. **Scrape health first.** `up{job="<job>"}` — is it 1 or 0? A
   flapping scrape invalidates all subsequent metrics.
   ```sh
   curl -sG "$YAI_VMETRICS_URL/api/v1/query" \
     --data-urlencode 'query=up{job="<job>"}' | jq '.data.result[].value[1]'
   ```

3. **Discover metric names.** For an unfamiliar service, list what
   the scraper actually sees:
   ```sh
   curl -s "$YAI_VMETRICS_URL/api/v1/label/__name__/values" \
     | jq -r '.data[]' | grep '<prefix>'
   ```

4. **Saturation signals by service:**
   - `litellm` → request rate, error rate, latency (`litellm_*`)
   - `n8n` → workflow execution rate, error count (`n8n_*`)
   - `windmill` → job queue depth, worker utilisation (`windmill_*`)
   - `qdrant` → vectors indexed, query latency (`app_*`)
   - `minio` → requests/s, errors, storage bytes (`minio_*`)
   - `vmagent` → remote_write lag, scrape errors (`vmagent_*`)
   - `victoria-metrics` → ingestion rate, slow queries (`vm_*`)

5. **Answer the prompt.** Tie findings to metric queries you ran.

## Output format

```
service: <svc>   job: <job>   window: <window>
scrape: <up | flapping | down>

Saturation:
  <metric>: <current>  (p95=<p95>)
  ...

Anomalies:
  1. [<severity>] <metric> <observation>  →  <likely cause>
  ...

Recommendations:
  1. <action> — file: <path>
```

## Don'ts

- Don't quote a metric without first verifying it exists.
- Don't apply label matchers outside both sides of a binop.
- Read-only. No metric writes or vmagent config changes.
