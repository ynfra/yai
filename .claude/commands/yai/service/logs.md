---
description: Tail docker compose logs for one yai service and interpret what's there
argument-hint: <service> [<prompt>...]
allowed-tools: Read, Bash
---

Act as a senior operator managing the yai self-hosted AI stack. Goal:
tail recent docker logs for one service, classify what's signal vs noise,
and answer the user's specific question (or give a one-paragraph health
verdict if none was asked).

User input: $ARGUMENTS

## Inputs

- **`<service>`** — any service from the `yai` skill's service table
  (`litellm`, `langfuse`, `n8n`, `windmill`, `grafana`, `qdrant`,
  `minio`, `postgres`, `browserless`, `firecrawl`).
- **Prompt** — optional free-form question (e.g. *"why is it erroring"*,
  *"find startup failures"*, *"detect anomalies"*).

## Workflow

1. **Get recent logs.**
   ```sh
   ./yai.sh logs <service>
   # Or last N lines without following:
   ( cd <service> && docker compose logs --no-color --tail=200 )
   ```
   For multi-container services (langfuse, n8n, firecrawl) pull logs from
   all containers in that compose project.

2. **Classify each pattern.** Don't trust the substring `error` blindly:
   - **Real issue** — startup failure, crash loop, auth failure, DB
     connection refused, OOM
   - **Self-inflicted** — your own recent restart noise, expected initial
     migrations
   - **Benign** — health-check noise, periodic log lines, graceful EOF

3. **Answer the prompt.** If the user asked a specific question, tie the
   answer to actual log lines with timestamps. If no question, give a
   one-paragraph verdict.

## Output format

```
service: <svc>   containers: <N>   lines sampled: <N>

VERDICT: <one line — HEALTHY / ERRORING / STARTING / DEGRADED>

Notable patterns:
  1. [REAL]    <pattern> × <count>  →  <root cause>
  2. [BENIGN]  <pattern> × <count>  →  <why benign>

Recommendations (if any):
  1. <action>
```

## Don'ts

- Don't tail logs indefinitely — use `--tail=200` or a fixed window.
- Don't manufacture issues. If the service looks healthy, say so.
- Don't restart the service — surface the recommendation, let the user
  decide.
