# litellm — OpenAI-compatible LLM gateway

[LiteLLM](https://www.litellm.ai/) proxy: a single OpenAI-compatible endpoint
that fronts 100+ LLM providers (OpenAI, Anthropic, OpenRouter, Bedrock, Vertex,
Azure, Together, Groq, …). It handles virtual API keys, per-key spend tracking
and budgets, routing, fallbacks, rate limits, and request/response logging.

Other yai stacks (n8n, windmill, agent code, etc.) should point their LLM
clients at this proxy instead of calling provider SDKs directly — that way
keys, quotas, and observability are managed in one place.

## Image

- `litellm/litellm:v1.85.0` — pinned via `LITELLM_VERSION` in `.env`.
- Registry moved: Docker Hub (`litellm/litellm`). Old GHCR path (`ghcr.io/berriai/litellm`)
  stopped receiving stable builds after the March 2026 supply-chain incident.
- Tag policy: **always pin to a `vX.Y.Z` tag**. Never use `:latest` or
  `main-stable` in anything you care about — those move under you.
- **DB requirement**: v1.84+ requires a working postgres connection at startup
  (Prisma migration runs before the HTTP server binds). Ensure `DATABASE_URL` is
  correct and the password uses URL-encoding for special chars (e.g. `!` → `%21`).
- **Security note**: skip `v1.82.7` and `v1.82.8`. A supply-chain incident in
  March 2026 affected those two builds; subsequent stable tags are clean.
  Before bumping the pin, cross-check the version against the advisory list:
  <https://github.com/BerriAI/litellm/security/advisories>.

## Ports

| Host | Container | Purpose |
|------|-----------|---------|
| 24000 | 4000 | OpenAI-compatible API + admin UI |

## Database

This stack does **not** bundle its own Postgres. It uses the shared
`yai-postgres` instance from `../postgres/`, reached from inside the container
via `host.docker.internal:25432` (wired through `extra_hosts: host-gateway`).

The shared Postgres **must be running first**. Recommended: create a
dedicated `litellm` database before the first start so LiteLLM's tables don't
share a schema with anything else:

```bash
docker exec -it yai-postgres psql -U yai -d yai -c 'CREATE DATABASE litellm;'
# then update DATABASE_URL in .env to end with /litellm instead of /yai
```

On first run LiteLLM will auto-create its own tables (Prisma migrations).

## First-time setup

```bash
# 1. Rotate the secrets in .env — both LITELLM_MASTER_KEY and LITELLM_SALT_KEY
#    must be changed from change_me. The SALT key is especially important:
#    once the DB has encrypted credentials, rotating it is destructive.
openssl rand -hex 32 | sed 's/^/sk-/'   # → LITELLM_MASTER_KEY
openssl rand -hex 32                    # → LITELLM_SALT_KEY

# 2. Make sure the shared Postgres is up, then start LiteLLM.
yai start postgres
yai start litellm
```

## Use

- **OpenAI-compatible API**: `http://localhost:24000/v1`
  - Drop-in replacement for the OpenAI base URL in any SDK.
  - Auth with `Authorization: Bearer <virtual_key>` (create virtual keys in
    the admin UI) or with the master key for admin operations.
- **Admin UI**: <http://localhost:24000/ui>
  - Log in with `LITELLM_MASTER_KEY`. Manage models, virtual keys, teams,
    spend limits, and view request logs.
- **Health**: <http://localhost:24000/health/liveliness>

Models can be configured two ways: declaratively in `config.yml` (good for
GitOps / reproducible setups) or via the admin UI (stored encrypted in the DB
when `STORE_MODEL_IN_DB=True`). Both work simultaneously.

## Observability — Langfuse integration

Wire LiteLLM into the Langfuse stack at `../langfuse/` to get full trace and
spend telemetry for every proxy call. Two options:

1. **Env vars** (simplest): set `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`,
   and `LANGFUSE_HOST` (e.g. `http://host.docker.internal:23000`) in `.env`
   and add `success_callback: ["langfuse"]` to `litellm_settings` in
   `config.yml`.
2. **Config-only**: set `litellm_settings.callbacks` in `config.yml` directly.

See LiteLLM's Langfuse callback docs for the exact flag names in the version
you're on.

## Docs & references

- LiteLLM docs home: <https://docs.litellm.ai/>
- Proxy deployment: <https://docs.litellm.ai/docs/proxy/deploy>
- Docker quick start: <https://docs.litellm.ai/docs/proxy/docker_quick_start>
- Releases: <https://github.com/BerriAI/litellm/releases>
- Security advisories (check before pinning a new version):
  <https://github.com/BerriAI/litellm/security/advisories>

## Operational notes

- `STORE_MODEL_IN_DB=True` means models added through the UI persist across
  restarts. Models in `config.yml` are reloaded from disk on every restart and
  always take precedence for their `model_name`.
- The `LITELLM_SALT_KEY` is used to encrypt provider API keys stored in the
  DB. Rotating it after data exists requires a manual re-encryption step —
  treat it like a database master key: generate once, back it up.
- The container only depends on `../postgres/` being reachable. If the proxy
  fails on boot with connection errors, check that `yai-postgres` is up and
  that `DATABASE_URL` matches its credentials and database name.
