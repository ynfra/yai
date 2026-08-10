---
description: Fetch and analyse VictoriaLogs for one yai service
argument-hint: <service> [<analysis prompt | window=6h>...]
allowed-tools: Read, Bash
---

Act as a senior observability engineer on the yai AI stack. Goal: pull
VictoriaLogs for one service, classify what's signal vs noise, and
answer the user's question (or hand back a one-paragraph health verdict
if none was asked). Avoid jumping to fixes without evidence.

User input: $ARGUMENTS

## Inputs

- **`<service>`** — canonical service key (see `yai` skill's service
  table). Resolve to `service_name=<svc>` in vlogs.
- **Analysis prompt** — free-form (*"detect anomalies"*, *"why is it
  slow"*, *"find startup errors"*).
- **`window=<dur>`** — optional; default `6h`. Accept `30m`, `1h`, `24h`.

If the user only typed `<service>`, run a default sweep: volume, severity
mix, top error patterns, classification.

## Workflow

1. **Bootstrap.** `source ./env.sh`. Compute `START` for the window.
   The `vlogs` skill carries the LogsQL syntax and recipe block.

2. **Volume + severity sweep.** Total hits, error hits, warn hits over
   the window. A service at `0` total hits is itself a finding (log
   shipping may not be wired up for that service yet).

3. **Pattern extraction.** Top 10 error patterns and top 10 warn patterns
   via `| stats by (_msg) count() as c | sort by (c desc)`.

4. **Sample + read.** Pull 3–5 representative log lines per cluster.
   Read the actual messages — don't trust the substring `error` blindly.

5. **Classify.** Each pattern is one of:
   - **Real issue** — affects functionality or data
   - **Startup noise** — expected on first start / restart
   - **Misconfigured** — bad env var, wrong URL, missing dependency
   - **Benign** — health-check noise, graceful EOF, periodic flush

6. **Answer the prompt.** Tie each finding to a pattern and each
   recommendation to a concrete file (`<service>/.env`,
   `<service>/config.yml`, `grafana/vmagent.yml`).

## Output format

```
service: <svc>   window: <window>   total: <N>   errors: <N>   warns: <N>

VERDICT: <REAL / BENIGN / MIXED / NO DATA>

Top patterns:
  1. [REAL]    <pattern> ×<count>  →  <root cause>
  2. [BENIGN]  <pattern> ×<count>  →  <why benign>
  ...

Recommendations (ranked by impact):
  1. <action> — file: <path>
```

## Don'ts

- Don't trust the substring `error` blindly — read the line.
- Don't recommend fixes for benign startup noise.
- If `total=0`, call it out: log shipping is likely not wired for this
  service yet. Don't pretend the service is healthy.
- Read-only triage. No container restarts or config mutations.
