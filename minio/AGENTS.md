# minio — S3-compatible object storage

Used as the artifact / blob store for the AI stack. Langfuse v3 brings its own
internal MinIO for trace blobs — this instance is for everything else
(model artifacts, RAG document caches, n8n/Windmill output, etc.).

## Image

- `pgsty/minio:RELEASE.2026-04-17T00-00-00Z` — maintained build by the Pigsty project.
- **Why not `minio/minio`?** The upstream `minio/minio` repository was archived
  on 2026-04-25 and the official images on Docker Hub / Quay have stopped
  receiving updates. `pgsty/minio` continues to publish maintained builds.
- Alternatives: Bitnami (`bitnami/minio:latest`) and Chainguard
  (`cgr.dev/chainguard/minio`) are also maintained options. For paid / enterprise
  features see `quay.io/minio/aistor/minio` (AIStor, licence required).

## Ports

| Host | Container | Purpose |
|------|-----------|---------|
| 25000 | 9000 | S3 API |
| 25001 | 9001 | Web console |

## Persistence

- `./data/` → `/data` (bind mount)

Data layout follows MinIO's standard `<bucket>/<key>` filesystem structure;
do not delete anything under `./data/` while the service is running.

## First-time setup

```bash
# Set MINIO_ROOT_USER and MINIO_ROOT_PASSWORD in .env first
../yai.sh init minio
../yai.sh start minio
```

Open the console at <http://localhost:25001> and log in with the root
credentials. The `MINIO_DEFAULT_BUCKETS` list (default: `yai`) is created on
first start.

## Docs & references

- Bitnami image: <https://hub.docker.com/r/bitnami/minio>
- Bitnami source / env vars: <https://github.com/bitnami/containers/tree/main/bitnami/minio>
- MinIO docs: <https://min.io/docs/minio/linux/index.html>
- MinIO client (`mc`) reference: <https://min.io/docs/minio/linux/reference/minio-mc.html>
- Chainguard alt image: <https://images.chainguard.dev/directory/image/minio/overview>
- Bitnami env var reference (BUCKETS etc.): <https://github.com/bitnami/containers/blob/main/bitnami/minio/README.md>

## Operational notes

- The MinIO Client (`mc`) is the canonical management tool — it is bundled
  inside the container (`docker exec -it yai-minio mc …`).
