# node-exporter

Prometheus Node Exporter — exposes host OS metrics (CPU, memory, disk, network)
for the Docker VM. Scraped by vmetrics under job `node_exporters`.

No host port is exposed; vmetrics reaches it by container name on `yai-infra`
(`yai-node-exporter:9100`).

## Data

No persistent state — stateless exporter reading live kernel interfaces.

## Upstream

- Docker Hub: https://hub.docker.com/r/prom/node-exporter
- GitHub: https://github.com/prometheus/node_exporter
- Releases: https://github.com/prometheus/node_exporter/releases
