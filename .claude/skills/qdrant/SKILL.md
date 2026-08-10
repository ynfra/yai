---
name: qdrant
description: Qdrant vector database on the yai stack — collection management, vector search, payload filtering, snapshot API, HTTP recipes. Auto-load on Qdrant, vector DB, embeddings, RAG, collection, similarity search, snapshot questions.
when_to_use: Load when the user asks about vector search, embeddings, RAG pipelines, collection management, upsert operations, filtered search, or snapshots. Also load when the user wants to store or retrieve vectors from any source, or when debugging Qdrant collection indexing.
allowed-tools: Bash(curl *)
---

# Qdrant

High-performance vector similarity search engine. URL: `YAI_QDRANT_URL` (port 26000).
gRPC on port 26001. Web UI: `http://localhost:26000/dashboard`.

## Auth

Optional. If `QDRANT_API_KEY` is set in `.env`, every request requires:
```
-H "api-key: <QDRANT_API_KEY>"
```
Check `qdrant/.env` — if `QDRANT_API_KEY` is absent or empty, auth is effectively disabled.

```sh
source ./env.sh
# If QDRANT__SERVICE__API_KEY is set in qdrant/.env, add: -H "api-key: $QDRANT_API_KEY"
# Health check (no auth required regardless of key setting)
curl -s "$YAI_QDRANT_URL/healthz"

# List collections (add -H "api-key: ..." if auth is enabled)
curl -s "$YAI_QDRANT_URL/collections" | jq '.result.collections[].name'
```

## Collections

```sh
# Create a collection (cosine, 1536-dim for OpenAI ada-002 / text-embedding-3-small)
curl -s -X PUT "$YAI_QDRANT_URL/collections/my_collection" \
  -H 'Content-Type: application/json' \
  -d '{
    "vectors": {
      "size": 1536,
      "distance": "Cosine"
    }
  }' | jq

# Get collection info (vector count, indexing status)
curl -s "$YAI_QDRANT_URL/collections/my_collection" | jq '.result | {status, vectors_count, points_count}'

# Delete a collection
curl -s -X DELETE "$YAI_QDRANT_URL/collections/my_collection"
```

## Upsert & search

```sh
# Upsert points
curl -s -X PUT "$YAI_QDRANT_URL/collections/my_collection/points" \
  -H 'Content-Type: application/json' \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, ...], "payload": {"text": "hello", "source": "doc1"}}
    ]
  }'

# Vector search (top-5, with payload)
curl -s -X POST "$YAI_QDRANT_URL/collections/my_collection/points/search" \
  -H 'Content-Type: application/json' \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5,
    "with_payload": true
  }' | jq '.result[] | {id, score, payload}'

# Filtered search (only docs from a specific source)
curl -s -X POST "$YAI_QDRANT_URL/collections/my_collection/points/search" \
  -H 'Content-Type: application/json' \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5,
    "filter": {"must": [{"key": "source", "match": {"value": "doc1"}}]},
    "with_payload": true
  }' | jq '.result[].payload'
```

## Snapshots (backup)

```sh
# Create snapshot for a collection (lands in ./data/snapshots/)
curl -s -X POST "$YAI_QDRANT_URL/collections/my_collection/snapshots" | jq

# List snapshots
curl -s "$YAI_QDRANT_URL/collections/my_collection/snapshots" | jq '.result[].name'

# Download a snapshot
curl -O "$YAI_QDRANT_URL/collections/my_collection/snapshots/<snapshot-name>"
```

## Operational notes

- **Telemetry disabled** — `QDRANT__TELEMETRY_DISABLED=true` is already set in the compose file.
- **Memory**: vector indices are memory-mapped. Large collections need generous host RAM. Tune `hnsw_config` (ef_construct, m) per collection for recall vs speed tradeoffs.
- **Prometheus metrics** at `/metrics` — already scraped by vmetrics (`job: qdrant`).
- **Embeddings source**: use LiteLLM at `http://host.docker.internal:24000/v1/embeddings` to generate vectors — routes to OpenAI, OpenRouter, or any configured upstream.

## Gotchas

- **Auth header name is `api-key`, not `Authorization`.** All requests need `-H "api-key: <QDRANT_API_KEY>"` when auth is enabled, not `Bearer`.
- **Check if auth is enabled first.** `curl -s "$YAI_QDRANT_URL/healthz"` always works without auth. A 401 on `/collections` confirms auth is active.
- **Embeddings: use LiteLLM.** Don't call OpenAI directly from scripts — route through `http://host.docker.internal:24000/v1/embeddings` to get spend tracking and model routing.
