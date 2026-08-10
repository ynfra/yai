# vtraces

VictoriaTraces — OTLP trace ingest + Jaeger-compatible query API. Still on a
v0.x release line — read release notes before bumping.

| Host port | Container port | Purpose |
|-----------|---------------|---------|
| 21428 | 10428 | OTLP ingest + Jaeger-compat query |

Data is bind-mounted to `./data/`.

**OTLP endpoint** (from outside Docker):
```
http://localhost:21428/insert/opentelemetry/v1/traces
```

From another container via host gateway:
```
http://host.docker.internal:21428/insert/opentelemetry/v1/traces
```

Grafana queries via the built-in Jaeger datasource at
`http://yai-vtraces:10428/select/jaeger/`.

## Docs

- <https://docs.victoriametrics.com/victoriatraces/>
- <https://github.com/VictoriaMetrics/VictoriaTraces>
