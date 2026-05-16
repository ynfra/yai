---
description: Restart one yai service (state-changing — confirms before acting)
argument-hint: <service>
allowed-tools: Read, Bash
---

Act as a senior operator managing the yai self-hosted AI stack. Goal:
restart one service, verify it comes back healthy, and report the
outcome.

User input: $ARGUMENTS

## Inputs

- **`<service>`** — a service from the `yai` skill's service table.

## Workflow

1. **Identify the service.** Resolve `$ARGUMENTS` to a canonical service
   name. Validate it's in the known list from `AGENTS.md`:
   `postgres minio qdrant browserless firecrawl n8n litellm langfuse windmill grafana`

2. **Check current state** before restarting.
   ```sh
   ./yai.sh ps <service>
   ```

3. **Restart.**
   ```sh
   ./yai.sh restart <service>
   ```

4. **Verify health** — wait for the health check to resolve (don't use a
   bare `sleep`):
   ```sh
   until docker inspect yai-<service> --format '{{.State.Health.Status}}' \
     2>/dev/null | grep -q "healthy\|unhealthy"; do sleep 3; done
   ./yai.sh ps <service>
   ( cd <service> && docker compose logs --no-color --tail=50 )
   ```
   For services without a Docker health check, poll the HTTP endpoint instead.
   For services with health endpoints, probe them:
   - `litellm` → `curl -s $YAI_LITELLM_URL/health/liveliness`
   - `grafana` → `curl -s $YAI_GRAFANA_URL/api/health`
   - `qdrant` → `curl -s $YAI_QDRANT_URL/healthz`
   - `langfuse` → `curl -s $YAI_LANGFUSE_URL/api/public/health`

5. **If still unhealthy after restart**, dig into logs before giving up:
   - `P1000: Authentication failed` (litellm) → DB credential mismatch in
     `.env.local`. Restart alone will not fix it. See litellm skill.
   - Container exits immediately → check for missing required env vars.
   - `health: starting` that never resolves → the healthcheck command may be
     failing silently; check with `docker inspect yai-<service>`.

6. **Report.** State before/after, any startup errors, verdict.

## `restart` vs `stop` + `start` (env var changes)

`./yai.sh service <svc> restart` maps to `docker compose restart` — containers are reused in-place. **Changes to `.env` or `.env.local` are NOT picked up.**

To apply any env var change, use a full down/up cycle:
```sh
./yai.sh stop <svc>
./yai.sh start <svc>
```
This recreates the containers and re-reads all env files.

## Don'ts

- Don't restart `postgres` while `litellm` is running without first
  stopping `litellm` — it holds open connections and may not recover
  automatically.
- Don't restart `grafana/victoriametrics` during active scrape bursts
  — the vmagent WAL handles brief downtime but report the risk.
- Source `./env.sh` before probing health endpoints.
- Don't use `sleep N` to wait for startup — use an `until` loop on
  `docker inspect` health status instead (bare sleep commands are blocked).
