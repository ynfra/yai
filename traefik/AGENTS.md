# traefik — HTTP reverse proxy + navigation dashboard

Traefik v3 in HTTP-only mode. Routes `*.localhost` subdomains to yai services
and serves a self-contained HTML navigation dashboard at `http://localhost:27000`.

## Ports

| Port  | Purpose |
|-------|---------|
| 27000 | HTTP entrypoint — dashboard and `*.localhost:27000` routing |
| 27001 | Traefik built-in API + dashboard (insecure, dev only) |

## Routing

Requests to `<service>.localhost:27000` are proxied to the service's host port
via `host.docker.internal:<port>`.

| Hostname | → Service port |
|---|---|
| `localhost:27000` | dashboard (nginx, internal) |
| `litellm.localhost:27000` | :24000 |
| `langfuse.localhost:27000` | :23000 |
| `n8n.localhost:27000` | :26002 |
| `windmill.localhost:27000` | :28000 |
| `qdrant.localhost:27000` | :26000 |
| `minio.localhost:27000` | :25001 |
| `browserless.localhost:27000` | :26003 |
| `firecrawl.localhost:27000` | :21000 |
| `grafana.localhost:27000` | :22000 |
| `vmetrics.localhost:27000` | :28428 |
| `vlogs.localhost:27000` | :29428 |
| `vtraces.localhost:27000` | :21428 |

`*.localhost` resolves to `127.0.0.1` on most OSes (RFC 6761), so no
`/etc/hosts` edits are required.

## Files

```
traefik/
├── docker-compose.yml    # Traefik + nginx for dashboard
├── traefik.yml           # Static Traefik config (entrypoint, api, ping, file provider)
├── config/
│   └── dynamic.yml       # HTTP routers + services (file provider, hot-reload)
└── dashboard/
    └── index.html        # Self-contained navigation page (inline CSS + JS)
```

## Configuration

`traefik.yml` is the static config (restart required on change).
`config/dynamic.yml` is watched by Traefik — edits apply without restart.

To add a new route, append a router + service pair to `config/dynamic.yml`.

## No TLS

TLS is intentionally omitted. Add a `tls` stanza + cert resolver to
`traefik.yml` if you later want HTTPS (e.g., with Let's Encrypt and a real
domain, or a self-signed cert with Traefik's built-in CA).

## Upstream docs

- Traefik v3 concepts: https://doc.traefik.io/traefik/
- File provider: https://doc.traefik.io/traefik/providers/file/
- Releases: https://github.com/traefik/traefik/releases
