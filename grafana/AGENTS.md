# grafana — visualisation UI

Grafana UI only. The backing observability stores are each a separate compose
project in their own folder, all connected via the `yai-infra` Docker network.

| Service | Folder | Description |
|---------|--------|-------------|
| VictoriaMetrics | `vmetrics/` | Metrics store + built-in scraper |
| VictoriaLogs | `vlogs/` | Log store (LogsQL, Loki-compat) |
| VictoriaTraces | `vtraces/` | Trace store (OTLP + Jaeger-compat) |
| Grafana | `grafana/` | This service |

## Ports

| Host | Container | Purpose |
|------|-----------|---------|
| 22000 | 3000 | Grafana UI |

Data is bind-mounted to `./data/grafana/`.

## First-time setup

```bash
# 1. Create the shared Docker network (once per host).
docker network create yai-infra

# 2. Start the obs stack in order.
./yai.sh start vmetrics
./yai.sh start vlogs
./yai.sh start vtraces
./yai.sh start grafana

# 3. Open Grafana — plugins install and datasources provision on first boot.
open http://localhost:22000
```

## Datasource URLs (container-name DNS on yai-infra)

Datasources are auto-provisioned from `provisioning/datasources/datasources.yaml`.
No manual UI setup needed.

| Datasource | Type | UID | URL |
|------------|------|-----|-----|
| vmetrics | `prometheus` (built-in) | `vmetrics` | `http://yai-vmetrics:8428` |
| vlogs | `victoriametrics-logs-datasource` | `vlogs` | `http://yai-vlogs:9428` |
| vtraces | `grafana-jaeger-datasource` | `vtraces` | `http://yai-vtraces:10428/select/jaeger/` |

## Dashboards

Pre-built dashboards are provisioned from `dashboards/` and load automatically on startup.
Folder structure maps to dashboard groups in Grafana UI.

| Folder | Contents |
|--------|----------|
| AMQP | RabbitMQ instance |
| DOCKER | cAdvisor (Docker containers) |
| INFRA | VictoriaMetrics, VictoriaLogs, VictoriaTraces, Grafana, AlertManager, vector |
| LB | Traefik, Traefik access log |
| LOGS | VictoriaLogs explore |
| NODE | Node Exporter (overview, full, disk) |
| PGSQL | PostgreSQL cluster, databases, activity, queries, pgbouncer, replication, TimescaleDB |
| REDIS | Redis instance |
| STORAGE | MinIO instance + bucket |

## Scrape targets

The built-in vmetrics scraper exposes its targets page at:
<http://localhost:28428/targets>

## Data migration (from the old monolithic grafana/ stack)

If you ran the old single-compose layout, move the data directories once:

```bash
./yai.sh stop grafana
mv grafana/data/victoriametrics  vmetrics/data
mv grafana/data/victorialogs     vlogs/data
mv grafana/data/victoriatraces   vtraces/data
mv grafana/data/vmagent          /tmp/  # discard WAL, safe to drop
# grafana/data/grafana stays where it is
```

## Image & version

| Image | Default tag |
|-------|-------------|
| `grafana/grafana` | `12.4.3` |

## Docs

- <https://grafana.com/docs/grafana/latest/>
- VictoriaMetrics plugin: <https://grafana.com/grafana/plugins/victoriametrics-metrics-datasource/>
- VictoriaLogs plugin: <https://github.com/VictoriaMetrics/victorialogs-datasource>
