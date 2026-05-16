---
name: windmill
description: Windmill script/workflow engine on the yai stack — REST API, worker types (default vs native), Python env quirks, dependency cache, scaling. Auto-load on Windmill, script engine, flow, worker, workspace, schedule questions.
when_to_use: Load when the user asks about Windmill scripts, flows, schedules, workers, or workspace management. Also load when debugging a Windmill job, adding a Python or TypeScript script, or setting up LiteLLM integration from within a Windmill script.
allowed-tools: Bash(curl *)
---

# Windmill

Developer platform for scripts, flows, and UIs in TypeScript, Python, Go, Bash, SQL.
URL: `YAI_WINDMILL_URL` (port 28000). UI and REST API share the same port.

## Architecture

| Container | Role |
|-----------|------|
| `windmill-server` | HTTP API, web UI, scheduler, job dispatcher |
| `windmill-worker` × 3 | Default workers — sandboxed nsjail per job, `default` queue |
| `windmill-worker-native` | Native worker — in-process, no sandbox, `native` queue |
| `postgres` | Workflows, jobs, secrets, audit log (internal to the compose project) |

## REST API

Base: `http://localhost:28000/api`  
Auth: `Authorization: Bearer <token>` — create tokens in UI: Settings → Tokens.

```sh
source ./env.sh
# Create a token: Windmill UI → Settings → Tokens → Add token
WM_TOKEN="<paste-token-here>"
WM="$YAI_WINDMILL_URL/api"

# List workspaces
curl -s -H "Authorization: Bearer $WM_TOKEN" "$WM/workspaces/list" | jq '.[].id'

# List scripts in a workspace
curl -s -H "Authorization: Bearer $WM_TOKEN" "$WM/w/<workspace>/scripts/list" | jq '.[].path'

# Run a script (returns job ID)
curl -s -X POST \
  -H "Authorization: Bearer $WM_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"args":{"key":"value"}}' \
  "$WM/w/<workspace>/jobs/run/p/<script-path>"

# Poll job result
curl -s -H "Authorization: Bearer $WM_TOKEN" \
  "$WM/w/<workspace>/jobs_u/completed/get/<job-id>" | jq '{success, result}'
```

## Worker types

| Worker | Queue | Isolation | Cold start | Good for |
|--------|-------|-----------|------------|----------|
| `windmill-worker` | `default` | nsjail sandbox | ~200–500 ms | untrusted scripts, long jobs |
| `windmill-worker-native` | `native` | in-process | ~0 ms | HTTP calls, transformations, glue |

Mark a script as **native** in the UI (Script → Settings → Worker group = `native`) to route it to the fast path.

## Python env quirks

- **Dependency cache** at `./data/cache` is shared across all default workers. First run of a script with new pip deps populates it; subsequent runs across any worker reuse it. Safe to wipe — it rebuilds on demand.
- Python scripts declare deps via a `requirements.txt`-style comment block at the top of the script:
  ```python
  # requirements:
  # httpx==0.27.0
  # pydantic>=2
  ```
- If a worker gets into a bad state due to stale cache, clear `./data/cache` and restart: `./yai.sh restart windmill`.

## LiteLLM integration

Any script calling an OpenAI-compatible endpoint should use:
```
base_url = "http://host.docker.internal:24000/v1"
api_key  = "<litellm-master-key>"
```

## Operational notes

- **No pre-seeded admin.** First browser visit creates the superadmin account and default workspace.
- **`BASE_URL`** in `.env` must be set if fronted by a reverse proxy — Windmill uses it to generate webhook and callback URLs.
- **Backups**: `pg_dump` the internal `windmill-postgres` container — contains every script, flow, schedule, and (encrypted) secret. `./data/cache` and `./data/logs` are disposable.
- **Scaling default workers**: increase `windmill-worker` `deploy.replicas`. For more native concurrency, bump `NUM_WORKERS` on `windmill-worker-native`.

## Gotchas

- **Workspace slug required in every path.** The API is `/api/w/<workspace>/...`. Calling `/api/scripts/list` directly returns 404. List workspace IDs first: `curl -s -H "Authorization: Bearer $WM_TOKEN" "$WM/workspaces/list" | jq '.[].id'`
- **First login creates superadmin.** No pre-seeded accounts — visit the UI once on first start to set the superadmin email and password.
- **`./yai.sh restart windmill` does not force-recreate.** If you changed `.env`, use `docker compose -f windmill/docker-compose.yml up -d --force-recreate` instead.
