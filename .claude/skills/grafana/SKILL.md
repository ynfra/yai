---
name: grafana
description: Grafana on the yai stack — datasource UIDs, file provisioning (not TF), dashboard conventions, scrape targets page, Grafana plugin setup. Auto-load on Grafana, dashboard, datasource, DS_*, panel, templating variable, provisioning questions.
when_to_use: Load when the user asks about Grafana dashboards, panels, datasources, Grafana API calls, provisioning files, plugin setup, or wants to view/create/update any dashboard or panel on the yai stack.
---

# Grafana

URL in env: `YAI_GRAFANA_URL` (port 22000). API token: `YAI_GRAFANA_TOKEN`.
Default admin login: `admin` / password set in `grafana/.env`.

## Provisioning

Grafana in the yai stack uses **file-based provisioning**, not the
Terraform provider. Datasources are provisioned via files mounted into
the container at `/etc/grafana/provisioning/datasources/`. Dashboards are
currently managed via the Grafana UI (first-time setup) — file
provisioning for dashboards is a reasonable follow-up.

The Grafana UI is write-enabled — edits you make in the UI persist in
`grafana/data/grafana/`. They are not committed to the repo.

## Datasources

Datasource URLs use compose internal service names (resolved from inside
the Grafana container, not from the host):

| Datasource | Type | Internal URL |
|-----------|------|-------------|
| VictoriaMetrics | `victoriametrics-metrics-datasource` | `http://victoriametrics:8428` |
| VictoriaLogs | `victoriametrics-logs-datasource` | `http://victorialogs:9428` |
| VictoriaTraces | `jaeger` | `http://victoriatraces:10428/select/jaeger/` |

**Don't substitute `localhost:<host_port>`** — those don't resolve from
inside the Grafana container.

## HTTP API quick-ref

```sh
source ./env.sh
H="Authorization: Bearer $YAI_GRAFANA_TOKEN"

# All dashboards
curl -s -H "$H" "$YAI_GRAFANA_URL/api/search?type=dash-db" \
  | jq '.[] | {uid, title, folderTitle}'

# One dashboard JSON
curl -s -H "$H" "$YAI_GRAFANA_URL/api/dashboards/uid/<UID>" | jq

# All datasources
curl -s -H "$H" "$YAI_GRAFANA_URL/api/datasources" \
  | jq '.[] | {uid, name, type}'

# Health check
curl -s "$YAI_GRAFANA_URL/api/health" | jq
```

## Scrape targets page

The easiest way to see which scrape jobs are up (served by VictoriaMetrics built-in scraper):
```sh
open "$YAI_VMETRICS_URL/targets"
# or as JSON
curl -s "$YAI_VMETRICS_URL/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, health}'
```

## Panel conventions

- Use PromQL/MetricsQL against VictoriaMetrics for metrics panels.
- Use LogsQL against VictoriaLogs for log panels (see `vlogs` skill).
- Trace panels use the Jaeger datasource against VictoriaTraces.
- Multi-select template variables in regex: use `:pipe` format.

## Grafana plugins (auto-downloaded on start)

`GF_INSTALL_PLUGINS` in `grafana/.env` triggers download from grafana.com
on container start. In an air-gapped setup, bake a custom Grafana image.

The two required Victoria* plugins:
- `victoriametrics-metrics-datasource` (VictoriaMetrics)
- `victoriametrics-logs-datasource` (VictoriaLogs)
