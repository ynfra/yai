# vlogs

VictoriaLogs — Loki-compatible log store with LogsQL query API.

| Host port | Container port | Purpose |
|-----------|---------------|---------|
| 29428 | 9428 | HTTP API (Loki push + LogsQL query) |

Data is bind-mounted to `./data/`.

**Push endpoint** (from outside Docker):
```
http://localhost:29428/insert/loki/api/v1/push
```

From another container on `yai-infra`:
```
http://yai-vlogs:9428/insert/loki/api/v1/push
```

Grafana queries at `http://yai-vlogs:9428` via the VictoriaLogs datasource plugin.

## Docs

- <https://docs.victoriametrics.com/victorialogs/>
- <https://github.com/VictoriaMetrics/VictoriaLogs>
