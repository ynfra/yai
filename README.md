# ynfra / yai

Self-hosted, docker-based AI infrastructure stack — LLM gateway, observability,
vector DB, object storage, workflow engines, browser fleet, and a
metrics/logs/traces backend. Each service is an isolated docker-compose project
managed by a single CLI (`./yai.sh`); the host has no GPU — all inference is
remote, brokered by LiteLLM.

![](docs/dashboard.png)

## Prerequisites

- [Docker Engine](https://docs.docker.com/engine/) ≥ 24 with [Compose v2](https://docs.docker.com/compose/).
- [OrbStack](https://orbstack.dev) (recommended for local development on macOS).

## Usage

```bash
# Create data directories and check for placeholder secrets
./yai.sh init all
# Edit each <service>/.env — replace every change_me value (openssl rand -hex 32)
# Bring up the stack, then check container status
./yai.sh stack start
./yai.sh ps all
```

CLI forms: `./yai.sh stack <cmd>` (every service), `./yai.sh service <name>
<cmd>` (one service), or the short `./yai.sh <cmd> [service|all]`.
Commands: `init | start | stop | restart | logs | ps | status | doctor |
orbstack install`.

## Services

| Service | URL | Port | Credentials |
|---|---|---|---|
| dashboard | <http://yai.orb.local> | — | no auth |
| litellm | <http://litellm.yai.orb.local/ui> | 24000 | `admin` / `litellm/.env.local` → `LITELLM_MASTER_KEY` |
| langfuse | <http://langfuse.yai.orb.local> | 23000 | sign up on first visit |
| grafana | <http://grafana.yai.orb.local> | 22000 | `admin` / `grafana/.env.local` → `GRAFANA_ADMIN_PASSWORD` |
| n8n | <http://n8n.yai.orb.local> | 26002 | create owner account on first visit |
| windmill | <http://windmill.yai.orb.local> | 28000 | `admin@windmill.dev` / `changeme` |
| firecrawl | <http://firecrawl.yai.orb.local> | 21000 | no auth |
| minio (console) | <http://minio.yai.orb.local> | 25001 | `minio/.env.local` → `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` |
| qdrant | <http://qdrant.yai.orb.local/dashboard> | 26000 | no auth |
| postgres | `yai.orb.local:25432` (TCP) | 25432 | user `yai`, DB `yai`, password in `postgres/.env.local` |
| vmetrics | <http://vmetrics.yai.orb.local> | 28428 | no auth |
| vlogs | <http://vlogs.yai.orb.local> | 29428 | no auth |
| vtraces | <http://vtraces.yai.orb.local> | 21428 | no auth |
| browserless | <http://browserless.yai.orb.local> | 26003 | no auth |
| Traefik API | <http://yai.orb.local:27001> | 27001 | no auth |

Traefik routes `*.yai.orb.local` to every service and serves a navigation
dashboard at <http://yai.orb.local> with one-click links to every service.

## Notes

- LiteLLM needs the shared Postgres: start `postgres` first, create its DB (`docker exec -it yai-postgres psql -U yai -d yai -c 'CREATE DATABASE litellm;'`), and point `DATABASE_URL` in `litellm/.env` at it.
- Windmill is not in the `yai.sh` SERVICES array — manage it with `docker compose` directly from `windmill/`.
- macOS development runs inside an OrbStack VM: `orb create debian:trixie yai`, then inside the machine (`orb -m yai`) run `./yai.sh orbstack install` and `./yai.sh doctor`.
- Each service folder supports a gitignored `.env.local` that overrides `.env` — ideal for personal/dev tweaks.

See [AGENTS.md](AGENTS.md) for the architecture, image versions, port
allocation, observability wiring, and agent rules.
