---
name: langfuse
description: Langfuse on the yai stack — LLM observability (traces, evals, prompt mgmt), REST API, SDK usage, Langfuse–LiteLLM callback wiring. Auto-load on Langfuse, LLM traces, evals, prompt management, observation, session questions.
when_to_use: Load when the user asks about LLM traces, evals, prompt management, observation sessions, or wants to debug why traces are not appearing in Langfuse. Also load when configuring the Langfuse SDK, wiring a callback from LiteLLM, or querying Langfuse via REST API.
allowed-tools: Bash(curl *)
---

# Langfuse

LLM observability: traces, evaluations, prompt management. URL in env:
`YAI_LANGFUSE_URL` (port 23000). Auth: public/secret key pair from env.

```sh
source ./env.sh
# Keys — must be set to real values after first setup
echo "Public: $YAI_LANGFUSE_PUBLIC_KEY"
echo "Secret: $YAI_LANGFUSE_SECRET_KEY"
```

The Langfuse stack embeds its own Clickhouse, MinIO, Redis, and Postgres.
Do not consolidate these onto the shared `postgres/` — they're not meant
to be merged.

## Endpoints

| Path | Purpose |
|------|---------|
| `/` | Web UI |
| `/api/public/metrics` | Prometheus metrics (scraped by vmagent as `langfuse-web`) |
| `/api/public/health` | Health check |
| `/api/public/traces` | Traces API (auth: Basic `pubkey:seckey`) |
| `/api/public/observations` | Observations (spans, generations) |
| `/api/public/sessions` | Session listing |
| `/api/public/prompts` | Prompt management |
| `/api/public/scores` | Eval scores |

## Auth

Langfuse REST API uses HTTP Basic auth with `public_key:secret_key`.

```sh
source ./env.sh
AUTH="$YAI_LANGFUSE_PUBLIC_KEY:$YAI_LANGFUSE_SECRET_KEY"

# Health
curl -s "$YAI_LANGFUSE_URL/api/public/health"

# List recent traces
curl -s -u "$AUTH" "$YAI_LANGFUSE_URL/api/public/traces?limit=10" \
  | jq '.data[] | {id, name, userId, totalTokens, latency}'

# Observations for a trace
curl -s -u "$AUTH" "$YAI_LANGFUSE_URL/api/public/observations?traceId=<id>" \
  | jq '.data[] | {type, model, promptTokens, completionTokens, latency}'
```

## LiteLLM callback wiring

Wire LiteLLM to Langfuse by adding to `litellm/config.yml`:

```yaml
litellm_settings:
  success_callback: ["langfuse"]

environment_variables:
  LANGFUSE_PUBLIC_KEY: os.environ/LANGFUSE_PUBLIC_KEY
  LANGFUSE_SECRET_KEY: os.environ/LANGFUSE_SECRET_KEY
  LANGFUSE_HOST: http://host.docker.internal:23000
```

And in `litellm/.env`:
```
LANGFUSE_PUBLIC_KEY=<from langfuse/.env>
LANGFUSE_SECRET_KEY=<from langfuse/.env>
```

## SDK tracing (from app code)

```python
from langfuse import Langfuse
import os

lf = Langfuse(
    public_key=os.getenv("LANGFUSE_PUBLIC_KEY"),
    secret_key=os.getenv("LANGFUSE_SECRET_KEY"),
    host=os.getenv("LANGFUSE_HOST", "http://localhost:23000"),
)
trace = lf.trace(name="my-workflow")
generation = trace.generation(
    name="llm-call", model="gpt-4o", input="prompt...", output="response..."
)
```

## Operational notes

- Langfuse v3 was a total architectural rewrite from v2. Do not mix
  `langfuse/langfuse:2` and `langfuse/langfuse:3` images.
- The `langfuse/` stack has its own MinIO on port 23090 — this is separate
  from the general-purpose `minio/` stack. Leave it alone.
- **Initial user/org seeding** is done via `LANGFUSE_INIT_*` env vars. All nine vars must be non-empty or the entire block is silently skipped. The required set:
  ```
  LANGFUSE_INIT_ORG_ID=<uuid>              # REQUIRED — triggers the whole block
  LANGFUSE_INIT_ORG_NAME=<name>
  LANGFUSE_INIT_PROJECT_ID=<uuid>
  LANGFUSE_INIT_PROJECT_NAME=<name>
  LANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-lf-<uuid>
  LANGFUSE_INIT_PROJECT_SECRET_KEY=sk-lf-<uuid>
  LANGFUSE_INIT_USER_EMAIL=<email>
  LANGFUSE_INIT_USER_NAME=<display name>
  LANGFUSE_INIT_USER_PASSWORD=<password>
  ```
  If `LANGFUSE_INIT_ORG_ID` is missing, the log will warn: `[Langfuse Init] LANGFUSE_INIT_ORG_ID is not set but other LANGFUSE_INIT_* variables are configured.`
  The seed is idempotent — safe to keep all vars set permanently; re-running on an existing DB upserts without wiping data.
