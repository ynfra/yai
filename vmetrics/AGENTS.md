# vmetrics

VictoriaMetrics single-node — metrics store + built-in Prometheus-compatible
scraper. No separate vmagent required; scraping is handled by the
`-promscrape.config` flag passed to the VM binary.

| Host port | Container port | Purpose |
|-----------|---------------|---------|
| 28428 | 8428 | HTTP API (remote_write + PromQL/MetricsQL query + `/targets`) |

Data is bind-mounted to `./data/`.

## Scrape config

Edit `promscrape.yml` in this folder. After editing, reload with:

```bash
./yai.sh restart vmetrics
```

Check scrape health at <http://localhost:28428/targets>.

Obs-stack peers (`yai-vlogs`) are reached by container name on `yai-infra`.
Sibling yai services are reached via `host.docker.internal:<host_port>`.

## Grafana datasource

Use the `VictoriaMetrics` plugin datasource at `http://yai-vmetrics:8428`.

## Docs

- <https://docs.victoriametrics.com/victoriametrics/>
- Built-in scraping: <https://docs.victoriametrics.com/victoriametrics/#how-to-scrape-prometheus-exporters-such-as-node-exporter>
