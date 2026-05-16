---
description: Check pinned versions against latest upstream releases for all yai services
argument-hint: [<service>]
allowed-tools: Bash, WebFetch
---

Act as a diligent platform engineer auditing the yai stack for outdated images.
Goal: compare every pinned image version in the repo against the latest upstream
release, then produce an actionable upgrade table.

User input (optional — filter to one service): $ARGUMENTS

## Workflow

### 1. Extract pinned versions

```sh
grep -h "image:" /Users/felix/Data/code/oss/ynfra/yai/*/docker-compose.yml \
  | grep -v "^\s*#" | sort -u
```

Also read `n8n/.env` for `N8N_VERSION` (the compose default is `:-latest`).

### 2. Fetch latest releases via WebFetch

For **each** service, call WebFetch on the URL below and extract the latest
stable (non-prerelease, non-draft) version tag.

| Service | WebFetch URL | What to extract |
|---|---|---|
| n8n | `https://github.com/n8n-io/n8n/releases/latest` | version number from redirect/page (strip `n8n@`) |
| grafana | `https://github.com/grafana/grafana/releases/latest` | tag like `v13.x.y` |
| qdrant | `https://github.com/qdrant/qdrant/releases/latest` | tag like `v1.x.y` |
| windmill | `https://github.com/windmill-labs/windmill/releases/latest` | tag like `v1.703.x` |
| langfuse | `https://github.com/langfuse/langfuse/releases/latest` | tag like `v3.x.y` |
| litellm | `https://github.com/BerriAI/litellm/releases/latest` | tag like `v1.x.y` |
| vmetrics | `https://github.com/VictoriaMetrics/VictoriaMetrics/releases/latest` | tag like `v1.x.y` |
| vlogs | `https://github.com/VictoriaMetrics/VictoriaLogs/releases/latest` | tag like `v1.x.y` |
| vtraces | `https://github.com/VictoriaMetrics/VictoriaTraces/releases/latest` | tag like `v0.x.y` |
| vector | `https://github.com/vectordotdev/vector/releases/latest` | tag like `v0.x.y` (skip `vdev-*` tags) |
| traefik | `https://github.com/traefik/traefik/releases/latest` | tag like `v3.x.y` |
| node-exporter | `https://github.com/prometheus/node_exporter/releases/latest` | tag like `v1.x.y` |
| minio (pgsty) | `https://github.com/pgsty/minio/releases/latest` | tag like `RELEASE.YYYY-MM-DDT…` |
| postgres | `https://hub.docker.com/r/library/postgres/tags?name=17.` | latest `17.x` tag |

**Browserless** and **firecrawl** are pinned to `:latest` — no release check needed,
just flag them as floating.

### 3. Compare and output

Strip leading `v`, `n8n@`, trailing `-debian`, `-alpine`, `-security-NN` suffixes
before comparing. Use string equality — any mismatch → OUTDATED.
Flag "security" in the tag name as HIGH priority.

## Output format

```
yai version audit — <date>
════════════════════════════════════════════════════════════

Service         Pinned          Latest          Status
───────────────────────────────────────────────────────────
n8n             2.21.3          X.Y.Z           ✓ / ↑ OUTDATED
grafana         12.4.3          X.Y.Z           ✓ / ↑ OUTDATED [⚠ SECURITY if applicable]
qdrant          v1.17.0         X.Y.Z           …
windmill        1.703.0         X.Y.Z           …
langfuse        3 (major)       3.X.Y           ℹ latest minor: 3.X.Y
litellm         v1.85.0         X.Y.Z           …
vmetrics        v1.143.0        X.Y.Z           …
vlogs           v1.50.0         X.Y.Z           …
vtraces         v0.8.2          X.Y.Z           …
vector          0.44.0-debian   X.Y.Z           …
traefik         v3.3            X.Y.Z           …
node-exporter   v1.9.1          X.Y.Z           …
postgres        17.10           —               check hub.docker.com/r/_/postgres tags
minio (pgsty)   RELEASE.…       RELEASE.…       …
browserless     :latest         —               floating tag, no pin
firecrawl       :latest         —               floating tag, no pin

OUTDATED SERVICES (N):
  → <service>  <pinned>  →  <latest>
     Upgrade: edit the default in <service>/docker-compose.yml, then:
     ( cd <service> && docker compose pull && docker compose up -d --force-recreate )
```

## Filtering

If `$ARGUMENTS` names a specific service, only WebFetch that one release page
and show its changelog link.

## Don'ts

- Don't write scripts — use WebFetch directly on the URLs above.
- Don't flag pre-release, alpha, beta, or rc tags as latest stable.
- Don't modify any files — report only.
- Don't perform upgrades — surface the commands for the user to run.
