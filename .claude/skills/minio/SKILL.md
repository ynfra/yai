---
name: minio
description: MinIO S3-compatible object storage on the yai stack — bucket ops, mc CLI, presigned URLs, policy management, S3 API recipes. Auto-load on MinIO, S3, object storage, bucket, presigned URL, mc, artifact storage questions.
when_to_use: Load when the user asks about MinIO buckets, object upload/download, presigned URLs, mc CLI, S3-compatible operations, or artifact storage. Also load when configuring another service to write to or read from MinIO.
allowed-tools: Bash(curl *) Bash(docker exec yai-minio *)
---

# MinIO

S3-compatible object storage. S3 API: `YAI_MINIO_URL` (port 25000).
Console: `YAI_MINIO_CONSOLE_URL` (port 25001).

Credentials in `minio/.env`: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`.

## S3 API — curl

```sh
source ./env.sh
# MinIO supports AWS SigV4; easier to use mc or the AWS SDK.
# For quick checks, the health endpoint needs no auth:
curl -s "$YAI_MINIO_URL/minio/health/live"   # → "" (200 = healthy)
curl -s "$YAI_MINIO_URL/minio/health/ready"  # → "" (200 = ready)
```

## mc CLI (MinIO Client)

`mc` is bundled inside the container. All operations go through `docker exec`:

```sh
# Alias (run once per shell session — or add to a script)
alias mc='docker exec -it yai-minio mc'

# List buckets
mc ls local/

# List objects in a bucket
mc ls local/yai/

# Copy a file in
mc cp /local/path/file.txt local/yai/subdir/file.txt

# Copy a file out
mc cp local/yai/subdir/file.txt /local/path/

# Remove an object
mc rm local/yai/subdir/file.txt

# Create a bucket
mc mb local/my-bucket

# Enable versioning on a bucket
mc version enable local/my-bucket

# Mirror a local directory into a bucket
mc mirror ./local-dir local/yai/backup/
```

The alias `local` is pre-configured inside the container pointing at `http://localhost:9000` with root credentials.

## Presigned URLs

Generate time-limited download URLs without exposing credentials:

```sh
# 24-hour presigned GET URL
docker exec -it yai-minio mc share download --expire 24h local/yai/path/to/file.txt

# 1-hour presigned PUT URL (for upload)
docker exec -it yai-minio mc share upload --expire 1h local/yai/path/to/file.txt
```

## Bucket policy

```sh
# Make a bucket public-read (useful for static assets)
docker exec -it yai-minio mc anonymous set public local/my-bucket

# Revert to private
docker exec -it yai-minio mc anonymous set none local/my-bucket

# Show current policy
docker exec -it yai-minio mc anonymous get local/my-bucket
```

## S3 SDK integration

Point any S3-compatible SDK at:
```
endpoint:   http://localhost:25000   (or http://host.docker.internal:25000 from inside a container)
access_key: <MINIO_ROOT_USER>
secret_key: <MINIO_ROOT_PASSWORD>
region:     us-east-1               (any value; MinIO ignores it)
force_path_style: true              (required — MinIO doesn't support virtual-hosted bucket names by default)
```

Python boto3 example:
```python
import boto3
s3 = boto3.client(
    "s3",
    endpoint_url="http://localhost:25000",
    aws_access_key_id="<user>",
    aws_secret_access_key="<password>",
    region_name="us-east-1",
)
s3.list_buckets()
```

## Operational notes

- **Image**: `pgsty/minio` (maintained fork — upstream `minio/minio` was archived 2026-04-25).
- **Default bucket** `yai` is created on first start via `MINIO_DEFAULT_BUCKETS`.
- **Langfuse has its own embedded MinIO** on port 23090 for trace payloads — do not confuse the two.
- **No named volumes** — data lives at `./data/` bind-mounted to `/data` inside the container.
