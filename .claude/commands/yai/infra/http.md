---
description: Issue an HTTP request against one yai service and interpret the response
argument-hint: <service> <path> [METHOD] [<analysis prompt>...]
allowed-tools: Read, Bash
---

Act as a senior operator on the yai AI stack. Goal: hit one service's
HTTP API at a specific path and interpret the response with service-aware
context.

User input: $ARGUMENTS

## Inputs

- **`<service>`** — canonical service key. Resolve to `YAI_<SVC>_URL`
  via the `yai` skill's service table.
- **`<path>`** — path under the service base (e.g. `/health/liveliness`,
  `/api/public/traces`, `/v1/models`). Begin with `/`.
- **`METHOD`** — optional; default `GET`.
- **Analysis prompt** — what to check or extract.

## Workflow

1. **Bootstrap.** `source ./env.sh`. Resolve `<service>` to its base URL.

2. **Issue the request.**
   ```sh
   BASE="${YAI_<SVC>_URL}"
   curl -fsS -X "${METHOD:-GET}" "$BASE$PATH" \
     ${NEEDS_AUTH:+-H "Authorization: Bearer $TOKEN"} \
     | jq .
   ```
   Auth conventions:
   - `grafana` → `Authorization: Bearer $YAI_GRAFANA_TOKEN`
   - `litellm` → `Authorization: Bearer $YAI_LITELLM_MASTER_KEY`
   - `langfuse` → `--user "$YAI_LANGFUSE_PUBLIC_KEY:$YAI_LANGFUSE_SECRET_KEY"`
   - All other yai services → no auth on internal endpoints.

3. **Interpret.** Non-2xx or empty response:
   - **Connection refused** — service is down. Check `./yai.sh ps <svc>`.
   - **404** — wrong path; check the service's AGENTS.md for API docs.
   - **5xx** — service error; pull logs with `/yai:service:logs`.
   - **401/403** — wrong key or token; check `<service>/.env`.

## Output format

```
service: <svc>  url: <BASE><PATH>  status: <code>  size: <bytes>

Response (truncated):
  <jq summary or first 30 lines>

Interpretation:
  <2–4 sentences>
```

## Don'ts

- Don't paste tokens into logs or output.
- Don't issue mutating requests (POST/PUT/DELETE) without the user
  explicitly asking. Default to read-only.
- Don't loop on connection errors — report once and stop.
