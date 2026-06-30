# yai — self-hosted AI stack environment.
# Usage: `source ./env.sh` from the repo root before running CLI tooling
# (curl probes, agent-browser, etc.). All services run on localhost ports
# — no VPN required.

# --- Observability stack (grafana/) ------------------------------------------
export YAI_GRAFANA_URL="http://localhost:22000"
export YAI_VMETRICS_URL="http://localhost:28428"
export YAI_VLOGS_URL="http://localhost:29428"
export YAI_VTRACES_URL="http://localhost:21428"
export YAI_VMAGENT_URL="http://localhost:28429"

# Convenience: Jaeger-compatible vtraces endpoint.
export YAI_VTRACES_JAEGER_URL="${YAI_VTRACES_URL}/select/jaeger"

# Grafana API token — create a service account token in Grafana
# (Administration → Service accounts → Add service account → Add token)
# then paste the token below (or export before sourcing).
export YAI_GRAFANA_TOKEN="${YAI_GRAFANA_TOKEN:-glsa_v7ciRwcJ0fFONuhN239twkeRBK3J2hHU_82acace7}"

# --- LLM gateway (litellm/) --------------------------------------------------
export YAI_LITELLM_URL="http://localhost:24000"
export YAI_LITELLM_MASTER_KEY="Admin1234!"

# --- LLM observability (langfuse/) -------------------------------------------
export YAI_LANGFUSE_URL="http://localhost:23000"
export YAI_LANGFUSE_PUBLIC_KEY="${YAI_LANGFUSE_PUBLIC_KEY:-pk-lf-ffeafe6e-9f4d-44a5-b838-c33cc8de144f}"
export YAI_LANGFUSE_SECRET_KEY="${YAI_LANGFUSE_SECRET_KEY:-sk-lf-b781e63c-2ecd-4805-81de-3385a3a6be4d}"

# --- Workflow engines ---------------------------------------------------------
export YAI_N8N_URL="http://localhost:26002"
export YAI_N8N_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlZTBjM2QzMy0yNmFiLTQzMzMtYjFkNC1iZjYxMzUzYWU5YTciLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiMmEzYTA3OTItMGUwNi00N2NmLWE0ZWYtM2Q5OWZiMWE4NzJhIiwiaWF0IjoxNzgyODMzODI3fQ.Me5CkkPzUGiOl5-hnagv33d9omOC-XC5mJGp_4ViRLg"
export YAI_WINDMILL_URL="http://localhost:28000"

# --- Data layer --------------------------------------------------------------
export YAI_QDRANT_URL="http://localhost:26000"
export YAI_MINIO_URL="http://localhost:25000"
export YAI_MINIO_CONSOLE_URL="http://localhost:25001"

# Shared Postgres (postgres/) — used by LiteLLM and ad-hoc workloads.
# Copy password from postgres/.env POSTGRES_PASSWORD after rotating it.
export YAI_POSTGRES_HOST="localhost"
export YAI_POSTGRES_PORT="25432"
export YAI_POSTGRES_USER="yai"
export YAI_POSTGRES_PASSWORD="${YAI_POSTGRES_PASSWORD:-e9ee8dc474a2ca35e779e609f25fc9ee647b8b3a5d59bc706255bf7688e5afa5}"
export YAI_POSTGRES_DB="yai"

# Convenience: full DSN for psql / any Postgres client.
export YAI_POSTGRES_DSN="postgresql://${YAI_POSTGRES_USER}:${YAI_POSTGRES_PASSWORD}@${YAI_POSTGRES_HOST}:${YAI_POSTGRES_PORT}/${YAI_POSTGRES_DB}"
export PGPASSWORD="${YAI_POSTGRES_PASSWORD}"

# --- Browser fleet -----------------------------------------------------------
export YAI_BROWSERLESS_URL="http://localhost:26003"
export YAI_FIRECRAWL_URL="http://localhost:21000"

# --- Traefik (traefik/) — HTTP proxy + navigation dashboard ------------------
export YAI_TRAEFIK_URL="http://localhost"              # dashboard + *.localhost routing (port 80)
export YAI_TRAEFIK_API_URL="http://localhost:27001"   # Traefik built-in API/dashboard
