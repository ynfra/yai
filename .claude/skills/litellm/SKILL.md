---
name: litellm
description: LiteLLM proxy on the yai stack — OpenAI-compatible API, virtual key management, model routing (config.yml), spend tracking, health endpoints, Langfuse callback wiring. Auto-load on LiteLLM, LLM gateway, model routing, virtual key, spend, config.yml, proxy questions.
when_to_use: Load when the user asks about LLM API calls, model routing, adding a new model, virtual keys, spend tracking, health checks, or debugging LiteLLM startup. Also load when diagnosing LLM-related errors from n8n or Windmill workflows, or when connecting any in-stack consumer to the LLM gateway.
allowed-tools: Bash(curl *)
---

# LiteLLM

OpenAI-compatible LLM gateway. URL in env: `YAI_LITELLM_URL` (port 24000).
Master key: `YAI_LITELLM_MASTER_KEY`.

LiteLLM is fully OpenAI API-compatible — use it anywhere an OpenAI SDK or credential is accepted.

### n8n credential setup

Create a credential of type **openAiApi** named `yai-litellm` (done once; reuse across workflows):

| Field | Value |
|-------|-------|
| API Key | LiteLLM master key (`YAI_LITELLM_MASTER_KEY`) |
| Base URL | `http://host.docker.internal:24000/v1` |

In every HTTP Request node that calls LiteLLM, set:
```json
"authentication": "predefinedCredentialType",
"nodeCredentialType": "openAiApi",
"credentials": { "openAiApi": { "id": "<cred-id>", "name": "yai-litellm" } }
```

Do **not** pass the key via env vars or `httpHeaderAuth` — the openAiApi predefined credential
injects `Authorization: Bearer <key>` automatically and survives the external runner sandbox.

## Endpoints

| Path | Purpose |
|------|---------|
| `/v1/chat/completions` | OpenAI-compatible chat (virtual key or master key) |
| `/v1/models` | List configured models |
| `/health` | Full health (checks all configured models) |
| `/health/liveliness` | Quick alive check |
| `/health/readiness` | DB connection check |
| `/ui` | Admin UI (log in with master key) |
| `/metrics` | Prometheus metrics (scraped by vmagent) |
| `/spend/logs` | Spend / request log (admin key required) |
| `/key/info` | Info about a virtual key |

## Auth

```sh
source ./env.sh
# Admin / any request using master key:
curl -s -H "Authorization: Bearer $YAI_LITELLM_MASTER_KEY" \
  "$YAI_LITELLM_URL/v1/models" | jq '.data[].id'

# Health (no auth needed)
curl -s "$YAI_LITELLM_URL/health/liveliness"
```

## Config file

Models and routing live in `litellm/config.yml`. Structure:

```yaml
model_list:
  - model_name: gpt-4o         # name exposed to callers
    litellm_params:
      model: openai/gpt-4o     # upstream model string
      api_key: os.environ/OPENAI_API_KEY

litellm_settings:
  success_callback: ["langfuse"]   # enable Langfuse tracing

environment_variables:
  LANGFUSE_PUBLIC_KEY: os.environ/LANGFUSE_PUBLIC_KEY
  LANGFUSE_SECRET_KEY: os.environ/LANGFUSE_SECRET_KEY
  LANGFUSE_HOST: http://host.docker.internal:23000
```

Changes to `config.yml` take effect on restart: `./yai.sh restart litellm`.
Models added via the admin UI with `STORE_MODEL_IN_DB=True` persist in
Postgres and survive restarts independently of `config.yml`.

## Spend & request log

```sh
source ./env.sh
# Last 20 requests with model and cost
curl -s -H "Authorization: Bearer $YAI_LITELLM_MASTER_KEY" \
  "$YAI_LITELLM_URL/spend/logs?limit=20" | jq '.[] | {model, total_cost, response_time_ms}'

# Total spend by model
curl -s -H "Authorization: Bearer $YAI_LITELLM_MASTER_KEY" \
  "$YAI_LITELLM_URL/spend/logs?limit=1000" \
  | jq 'group_by(.model) | map({model: .[0].model, total: (map(.total_cost) | add)}) | sort_by(.total) | reverse'
```

## Debugging

### Startup triage

Always start with logs, then cross-reference the health endpoint:

```sh
cd litellm && docker compose logs --no-color --tail=50
source ./env.sh && curl -s "$YAI_LITELLM_URL/health/liveliness"
```

Common Prisma/DB error patterns:

| Log pattern | Cause | Fix |
|-------------|-------|-----|
| `P1000: Authentication failed` | `DATABASE_URL` password in `litellm/.env` doesn't match the postgres `yai` password | Correct the `DATABASE_URL` in `litellm/.env`, then force-recreate |
| `P1001: Can't reach database server` | Postgres is down or `host.docker.internal` is unreachable | Start postgres first; verify connectivity |
| `migration failed but continuing startup` | Prisma ran but auth failed — proxy is up but runs without DB | Fix `DATABASE_URL`, then force-recreate |

When the DB password is wrong LiteLLM still starts (it soft-fails Prisma) but
**spend tracking and virtual keys do not persist**. Use `/health/readiness` to
confirm DB is actually connected:

```sh
source ./env.sh
curl -s -H "Authorization: Bearer $YAI_LITELLM_MASTER_KEY" \
  "$YAI_LITELLM_URL/health/readiness"
```

### `health: starting` never resolves

The Docker health check is failing. Don't use a bare `sleep` — poll until it
settles:

```sh
until docker inspect yai-litellm --format '{{.State.Health.Status}}' \
  | grep -q "healthy\|unhealthy"; do sleep 3; done && ./yai.sh ps litellm
```

If it lands on `unhealthy`, the healthcheck command itself is failing — inspect
with `docker inspect yai-litellm` to see the last health output.

## Operational notes

- **Security**: skip `v1.82.7` / `v1.82.8` (supply-chain incident, March 2026).
  Check advisories before bumping: `litellm/AGENTS.md` has the link.
- **`LITELLM_SALT_KEY`** encrypts provider API keys in the DB. Generate once
  and treat like a database master key — rotating it after data exists
  requires manual re-encryption.
- **Postgres dependency**: shared `yai-postgres` must be running and have a
  `litellm` database (`CREATE DATABASE litellm;` on first setup).
- LiteLLM exposes a Prometheus `/metrics` endpoint — vmagent already scrapes
  it (`job_name: litellm` in `grafana/vmagent.yml`).
- **`restart` vs `start`**: `./yai.sh restart <svc>` does not force-recreate
  containers, so new or changed env vars in `.env.local` are **not** picked up.
  Use `./yai.sh service <svc> start` (which passes `--force-recreate`) when
  `.env` has been updated.
