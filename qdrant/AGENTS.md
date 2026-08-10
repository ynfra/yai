# qdrant — vector database

High-performance vector similarity search engine. Used as the long-term memory
/ RAG backing store for the AI stack. Pairs naturally with `../litellm/` for
embeddings, with `../firecrawl/` feeding documents in,
and with `../n8n/` / `../windmill/` orchestrating ingestion pipelines.

## Image

- `qdrant/qdrant:v1.17.0` — latest stable.
- Tag policy: pin to a specific minor (`v1.13.1`); avoid floating `latest`.

## Ports

| Host  | Container | Purpose          |
|-------|-----------|------------------|
| 26000 | 6333      | REST API + Web UI |
| 26001 | 6334      | gRPC API         |

Web UI: <http://localhost:26000/dashboard>.

## Persistence

- `./data/` → `/qdrant/storage` (bind mount)

Collections, payload, and index data all live under `./data/`. Do not delete
anything under this path while the service is running.

## First-time setup

```bash
# Optional: set QDRANT_API_KEY in .env to require auth on every request
../yai.sh init qdrant
../yai.sh start qdrant

# Verify
curl http://localhost:26000/healthz
```

If you set `QDRANT_API_KEY`, every request must include
`-H "api-key: <value>"`.

## Docs & references

- Docs: <https://qdrant.tech/documentation/>
- Quickstart: <https://qdrant.tech/documentation/quickstart/>
- Docker image: <https://hub.docker.com/r/qdrant/qdrant>
- Release notes: <https://github.com/qdrant/qdrant/releases>
- Python client: <https://github.com/qdrant/qdrant-client>
- Rust source: <https://github.com/qdrant/qdrant>

## Operational notes

- Snapshots: use the `/collections/<name>/snapshots` API for point-in-time
  backups; output lands under `./data/snapshots/`.
- Telemetry is disabled via `QDRANT__TELEMETRY_DISABLED=true` in the compose
  file — Qdrant pings home with anonymous usage data by default.
- Memory: vector indices are memory-mapped; large collections benefit from
  generous host RAM. Tune `hnsw_config` per collection.
- Exposed `/metrics` (Prometheus format) endpoint is consumed by the
  `../grafana/` stack's vmagent (already wired in `grafana/vmagent.yml`).
