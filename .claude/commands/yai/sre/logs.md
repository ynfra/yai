---
description: Fan-out log triage across many yai services — subagents per service, synthesis verdict
argument-hint: [service | --all | --obs | --llm | --browser | --workflows | --data] [window=6h]
allowed-tools: Read, Bash
---

Act as a senior SRE on-call for the yai AI stack. Goal: sweep logs across
a set of services in parallel, classify what's signal vs noise per service,
then **synthesise a single cross-service verdict**. Group findings by root
cause — one underlying problem (e.g. a DB being down) often surfaces in
multiple services' logs.

User input: $ARGUMENTS

## Inputs

- **Service or group**:
  - Single service → triage one service.
  - `--obs` → grafana, vmetrics, vlogs, vtraces, vmagent
  - `--llm` → litellm, langfuse
  - `--browser` → browserless, firecrawl
  - `--workflows` → n8n, windmill
  - `--data` → postgres, minio, qdrant
  - `--all` → union of all groups
  - The authoritative list is in the `yai` skill.
- **`window=<dur>`** — optional; default `6h`.

## Workflow

1. **Bootstrap.** `source ./env.sh`. Resolve the target group to a
   concrete service list (use the `yai` skill's service groups).

2. **Fan out.** Spawn one Agent (subagent_type=`Explore`) per service,
   **in parallel** (single message, multiple Agent calls). Each subagent
   prompt:

   > Run `/yai:infra:logs <service> window=<window>` semantics. Pull
   > volume from VictoriaLogs (or docker logs if vlogs has 0 hits),
   > top error/warn patterns, classify each pattern (REAL / STARTUP-NOISE
   > / MISCONFIGURED / BENIGN), and report under 200 words. Cite raw log
   > samples by line. Use the `vlogs` skill for LogsQL syntax and the
   > `yai` skill for service identity.

   When the group has more than ~6 services, batch into rounds of ~6
   parallel agents.

3. **Synthesise.**
   - **Cluster findings by root cause.** One broken dependency (e.g.
     `postgres` down) may appear in `litellm`, `n8n`, and `windmill` logs
     simultaneously — that's one root cause, not three issues.
   - **Rank by impact.** Real issues first; misconfigured second; benign
     last.
   - **Quote evidence.** For every claim, name the service and the
     pattern that backs it.

4. **Recommend.** For each real issue: name the fix and the file.
   For benign noise: say "no action" and why.

## Output format

Lead with a per-service verdict line:

```
litellm      45 ERR / 0 WARN   — REAL: DB connection refused (postgres not running)
langfuse      0 hits            — NO DATA: log shipping not wired up yet
n8n           3 ERR / 12 WARN  — BENIGN: startup migration warnings on fresh install
windmill      0 ERR / 0 WARN   — HEALTHY
grafana       1 ERR             — REAL: VictoriaMetrics datasource not reachable
```

Then a **Cross-service synthesis** section grouping by root cause.

Then a **Recommendations** section, ranked by impact:
1. Concrete fixes with the owning file or command.
2. Things worth watching but not fixing today.
3. Things to ignore — say so explicitly.

It is OK — and often correct — to conclude **"no action needed, the
stack is healthy"**. Don't manufacture work.

## Don'ts

- Don't trust `error` substrings blindly — read the actual line.
- Don't probe in a tight loop on connection failure.
- Don't restart services from this command. Surface fixes; let the user
  apply them.
- Don't serialise the per-service sweep — fan out in parallel.
