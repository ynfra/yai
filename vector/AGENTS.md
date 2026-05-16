# Vector

Docker log collector for the yai stack. Tails Docker container logs from all
`yai-*` containers and ships them to VictoriaLogs via the Loki-compatible push
API. Also exposes internal Vector metrics for vmetrics scraping.

## Key details

| Item | Value |
|---|---|
| Image | `timberio/vector:0.44.0-debian` |
| Container name | `yai-vector` |
| Metrics endpoint | `http://localhost:9598/metrics` (internal, scraped by vmetrics) |
| Log sink | `http://yai-vlogs:9428/insert` (Loki push, on `yai-infra`) |
| Docker socket | `/var/run/docker.sock` (read-only) |
| Config file | `vector.yaml` (mounted into container) |

## Config overview (`vector.yaml`)

- **Source** `docker_logs` — tails all containers matching `yai-*`
- **Transform** `normalize` — strips `yai-` prefix → `service_name` label
- **Sink** `vlogs` — Loki push to VictoriaLogs with `{service_name, stream}` labels
- **Sink** `prometheus_exporter` — exposes Vector internal metrics on `:9598`

## Grafana dashboard

`grafana/dashboards/INFRA/vector.json` — shows Vector throughput, component
health, and buffer metrics. Uses `DS_VMETRICS` datasource.

## Upstream

- Releases: https://github.com/vectordotdev/vector/releases
- Docker Hub: https://hub.docker.com/r/timberio/vector
- Docs: https://vector.dev/docs/
- VRL reference: https://vector.dev/docs/reference/vrl/
