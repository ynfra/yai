---
name: n8n
description: n8n workflow automation on the yai stack — queue mode architecture, REST API, webhook patterns, credential setup, worker scaling, loop patterns, expression gotchas, CLI execution. Auto-load on n8n, workflow, execution, webhook, automation, queue mode questions.
when_to_use: Load when the user asks about n8n workflows, executions, webhooks, credentials, node configuration, queue mode, worker scaling, or expression syntax. Also load when debugging a failed execution, building a new workflow, or calling the n8n REST API.
allowed-tools: Bash(curl *)
---

# n8n

Low-code workflow automation, running in queue mode. URL: `YAI_N8N_URL` (port 26002).
UI + REST API + webhooks all share the same port.

## Architecture

| Container | Role |
|-----------|------|
| `yai-n8n-n8n-1` | Main — UI, API, webhook receiver, scheduler, task broker |
| `yai-n8n-n8n-worker-1` | Executes queued workflow runs from Redis |
| `yai-n8n-n8n-runner-1` | External task runner for `n8n` (JS Code-node isolation) |
| `yai-n8n-n8n-worker-runner-1` | External task runner for `n8n-worker` |
| `yai-n8n-redis-1` | Bull queue broker |
| `yai-n8n-postgres-1` | Workflows, executions, credentials (internal to the compose project) |

External runners (`N8N_RUNNERS_MODE=external`) sandbox user-supplied Code-node JS outside the main/worker containers.

## REST API

Base: `http://localhost:26002/api/v1`  
Auth: **API key** from `env.sh` as `YAI_N8N_TOKEN` (`X-N8N-API-KEY: <key>`).

```sh
source ./env.sh

# List workflows (id, active, name)
curl -s -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" "$YAI_N8N_URL/api/v1/workflows?limit=50" | \
  python3 -c "import json,sys; [print(w['id'], w['active'], w['name']) for w in json.load(sys.stdin)['data']]"

# Get one workflow (nodes + connections)
curl -s -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" "$YAI_N8N_URL/api/v1/workflows/<id>"

# Update a workflow (PUT — must send name + nodes + connections + settings)
curl -s -X PUT -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" -H "Content-Type: application/json" \
  --data @workflow.json "$YAI_N8N_URL/api/v1/workflows/<id>"

# Create a new workflow
curl -s -X POST -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" -H "Content-Type: application/json" \
  --data @workflow.json "$YAI_N8N_URL/api/v1/workflows"

# Delete a workflow
curl -s -X DELETE -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" "$YAI_N8N_URL/api/v1/workflows/<id>"

# Activate / deactivate
curl -s -X POST -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" "$YAI_N8N_URL/api/v1/workflows/<id>/activate"
curl -s -X POST -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" "$YAI_N8N_URL/api/v1/workflows/<id>/deactivate"

# List executions with status
curl -s -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" \
  "$YAI_N8N_URL/api/v1/executions?limit=20&status=error" | \
  python3 -c "import json,sys; [print(e['id'], e['status'], e.get('workflowId')) for e in json.load(sys.stdin)['data']]"

# Inspect a failed execution (find node error + message)
curl -s -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" \
  "$YAI_N8N_URL/api/v1/executions/<id>?includeData=true" | \
  python3 -c "
import json,sys
e=json.load(sys.stdin)
run=(e.get('data') or {}).get('resultData',{}).get('runData',{})
for node,runs in run.items():
    for r in (runs or []):
        err=r.get('error')
        items=sum(len(m or []) for m in ((r.get('data') or {}).get('main') or [[]]))
        print(f'{node:30s} items_out={items}' + (f'  ERR: {err[\"message\"]}' if err else ''))
"
```

**Note**: `POST /api/v1/workflows/:id/execute` is NOT available in n8n v2.21.3 (returns 405). Use CLI or webhooks instead.

### executeWorkflow node — workflowId format

`typeVersion: 1` requires a **plain string** ID:
```json
{ "workflowId": "abc123", "options": {} }
```

`typeVersion: 1.1` uses the resource-locator object:
```json
{ "workflowId": { "__rl": true, "value": "abc123", "mode": "id" }, "options": {} }
```

Mixing typeVersion 1 with the `__rl` format causes the UI to show "Workflow does not exist" even when the target workflow exists.

## Executing workflows

### Method 1 — CLI via docker exec (preferred)

```sh
# Execute any leaf workflow by ID
docker exec yai-n8n-n8n-1 n8n execute --id <WORKFLOW_ID>

# Raw JSON output (for scripting)
docker exec yai-n8n-n8n-1 n8n execute --id <WORKFLOW_ID> --rawOutput

# List all workflows
docker exec yai-n8n-n8n-1 n8n list:workflow
```

**Use this method first.** It runs synchronously and streams output directly.

**Limitation**: Workflows containing `Execute Workflow` nodes (sub-workflow calls) fail in CLI mode with "Workflow does not exist" — the CLI process can't resolve sub-workflows in queue mode. Run each sub-workflow separately instead.

### Method 2 — Webhook trigger (fallback for sub-workflow or async cases)

Use only when the workflow uses `Execute Workflow` nodes that fail under CLI, or when asynchronous
execution is explicitly needed.

Add a `Webhook Trigger` node to the workflow, then:
```sh
curl -X POST "$YAI_N8N_URL/webhook/<path>" \
  -H 'Content-Type: application/json' -d '{}'
```

Webhook URLs: `http://localhost:26002/webhook/<path>` (live) and `/webhook-test/<path>` (test only, requires open editor).

## Saving workflows to filesystem

```sh
source ./env.sh
curl -s -H "X-N8N-API-KEY: $YAI_N8N_TOKEN" "$YAI_N8N_URL/api/v1/workflows/<id>" | \
  python3 -c "import json,sys; w=json.load(sys.stdin); print(json.dumps({'name':w['name'],'nodes':w['nodes'],'connections':w['connections'],'settings':w.get('settings',{})},indent=2))" \
  > n8n/workflows/<slug>.json
```

## Loop pattern (splitInBatches)

**typeVersion 3** (current default) has **reversed** output port semantics vs typeVersion 1:

| typeVersion | Output 0 | Output 1 |
|-------------|----------|----------|
| 1 (legacy)  | batch items → processing | done signal → leave empty |
| 3 (current) | done signal → leave empty | batch items → processing |

Standard wiring for typeVersion 3:

```
Trigger → fetch N items → Loop[output 1] → process one item → Loop (loop-back)
                          Loop[output 0] → (nothing connected — done)
```

The loop-back signal just advances the internal pointer — items from the loop-back are discarded, not re-processed.

**Critical**: if any node in the processing chain emits **0 items**, nothing reaches the loop-back, and the loop stalls permanently for the remaining items. Always ensure every node on the processing path produces at least 1 output item.

## Expression gotchas

### Postgres node: always return 1 row from existence checks

```sql
-- WRONG: returns 0 rows for new items → loop stalls
SELECT id FROM table WHERE guid = '{{ $json.guid }}'

-- RIGHT: always returns 1 row with a boolean
SELECT (COUNT(*) = 0) AS is_new FROM table WHERE guid = '{{ $json.guid }}'
```

Then in the IF node, check `$json.is_new` with operator `boolean → true`.

### Do NOT use Postgres dollar-quoting in n8n expressions

```sql
-- WRONG: $body$ outside {{ }} confuses n8n's $-expression parser
INSERT INTO t (content) VALUES ($body${{ $json.text }}$body$)

-- RIGHT: use .replace() inside the expression
INSERT INTO t (content) VALUES ('{{ $json.text.replace(/'/g, "''") }}')
```

### Single quotes in node-name references

```js
// RIGHT — write directly; Python triple-quoted strings avoid double-escaping
$('Setup').item.json.title.replace(/'/g, "''")

// WRONG — backslash-escaped quotes break the expression parser
$(\'Setup\').item.json.title
```

When generating workflow JSON from Python, always use triple-quoted strings (`"""..."""`) to avoid `\'` leaking into the serialised JSON.

### COUNT(*) returns bigint — use boolean, not number comparison

```sql
-- If you must use COUNT, cast or compare in SQL:
SELECT (COUNT(*) = 0) AS is_new ...   -- boolean, works reliably in IF node

-- Avoid: COUNT(*) returns '0' as string in some n8n versions, breaking number IF
```

### IF node typeValidation

Use `typeValidation: "loose"` in IF conditions whenever the left value might be a number, boolean, or string depending on context. `strict` causes type-mismatch errors.

## Workflow JSON structure for API calls

Minimum payload for `POST /workflows` and `PUT /workflows/:id`:

```json
{
  "name": "My Workflow",
  "nodes": [...],
  "connections": { "NodeName": { "main": [[{"node": "Next", "type": "main", "index": 0}]] } },
  "settings": { "executionOrder": "v1" }
}
```

`settings` must not contain `binaryMode` (causes 400 validation error). Always use `executionOrder: "v1"`.

## Slack integration

Use `messageType: "text"` with mrkdwn — do **not** use `messageType: "block"`.

The Slack node v2.3 with `messageType: "block"` omits the required `text` fallback from the API call, causing Slack to reject with `no_text`. Always build the message as a formatted string in a Code node and pass it to the Slack node as:

```json
{
  "typeVersion": 2.4,
  "select": "channel",
  "channelId": { "__rl": true, "value": "#channel-name", "mode": "name" },
  "text": "={{ $json.message }}",
  "otherOptions": { "includeLinkToWorkflow": false }
}
```

- Channel value must include the `#` prefix when using `mode: "name"`
- `includeLinkToWorkflow: false` removes the "Automated with this n8n workflow" footer
- mrkdwn formatting in `text` renders bold (`*text*`), links (`<url|label>`), and line breaks (`\n`) correctly in Slack

## LiteLLM integration

LiteLLM is OpenAI-compatible. In n8n, use the **openAiApi** predefined credential type.

**Credential** (create once in n8n Settings → Credentials):
- Type: `openAiApi`, Name: `yai-litellm`
- API Key: LiteLLM master key (`YAI_LITELLM_MASTER_KEY`)
- Base URL: `http://host.docker.internal:24000/v1`

**HTTP Request node** (typeVersion 4.4) calling LiteLLM endpoints:
```json
{
  "authentication": "predefinedCredentialType",
  "nodeCredentialType": "openAiApi",
  "credentials": { "openAiApi": { "id": "<cred-id>", "name": "yai-litellm" } }
}
```
This injects `Authorization: Bearer <key>` automatically and works in external runner mode.

**Do not** use `genericCredentialType: "httpHeaderAuth"` — headers are silently dropped by the
external runner sandbox. Do not inject the key via env vars (`N8N_PUBLIC_ENVS`).

For `lmChatOpenAi` nodes, use credential `yai-litellm` and set model via `{"__rl": true, "value": "openrouter/openai/gpt-oss-120b:free", "mode": "id"}`.

## Node versioning — finding and upgrading typeVersion

### What typeVersion is

Every n8n node embeds a `typeVersion` in the workflow JSON. When a node is
outdated the n8n UI shows a yellow badge: *"Version X.Y (Latest: A.B)"*.
Nodes keep working on the old version but may miss new parameters or bug fixes.

### Finding the latest version

**Option 1 — n8n UI (fastest)**
Open any workflow containing the node. The yellow badge names both versions.

**Option 2 — GitHub source (authoritative)**
Each node's TypeScript file declares its supported versions:
```
n8n-nodes-base:          https://github.com/n8n-io/n8n/tree/master/packages/nodes-base/nodes/
@n8n/n8n-nodes-langchain: https://github.com/n8n-io/n8n/tree/master/packages/@n8n/nodes-langchain/nodes/
```
Look for `version: [1, 2, 3]` (max = latest) or `defaultVersion: 3`.
Many nodes have been reorganised; common moves:
- Transform nodes (`aggregate`, `removeDuplicates`, `sort`, `splitOut`,
  `summarize`) → `nodes/Transform/<Name>/`
- `executeWorkflow` + trigger → `nodes/ExecuteWorkflow/…/`
- `scheduleTrigger` → `nodes/Schedule/ScheduleTrigger.node.ts`

Use raw URLs for scripted lookups:
```
https://raw.githubusercontent.com/n8n-io/n8n/master/packages/nodes-base/nodes/HttpRequest/HttpRequest.node.ts
https://raw.githubusercontent.com/n8n-io/n8n/master/packages/%40n8n/nodes-langchain/nodes/agents/Agent/Agent.node.ts
```

### Comparing all workflows at once

```python
import json, glob

node_versions = {}
for wf_path in glob.glob('n8n/workflows/*.json'):
    with open(wf_path) as f:
        data = json.load(f)
    for node in data.get('nodes', []):
        ntype = node.get('type', '')
        if not ntype.startswith(('n8n-nodes-base.', '@n8n/n8n-nodes-langchain.')):
            continue
        ver = node.get('typeVersion')
        node_versions.setdefault(ntype, set()).add(ver)

for ntype, vers in sorted(node_versions.items()):
    print(f'{ntype}: {sorted(vers)}')
```

### Bulk upgrade script

```python
import json, glob

UPGRADES = {
    # map: node_type → (current_version, target_version)
    'n8n-nodes-base.httpRequest': (4.2, 4.4),
    # add more entries as needed
}

for wf_path in glob.glob('n8n/workflows/*.json'):
    with open(wf_path) as f:
        data = json.load(f)
    changed = False
    for node in data.get('nodes', []):
        if node.get('type') in UPGRADES:
            old, new = UPGRADES[node['type']]
            if node.get('typeVersion') is not None and abs(float(node['typeVersion']) - float(old)) < 0.001:
                node['typeVersion'] = new
                changed = True
    if changed:
        with open(wf_path, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
```

Use `abs(float(cur) - float(old)) < 0.001` for comparison — JSON stores
some versions as `int` (e.g. `1`) and others as `float` (e.g. `1.1`), and
direct `==` can miss integer/float mismatches.

### Known latest versions (n8n 2.21.3, checked 2026-05-19)

Update this table when upgrading the n8n image — versions track n8n releases.

| Node | Latest | Node | Latest |
|---|---|---|---|
| `n8n-nodes-base.aggregate` | 1 | `@n8n/…langchain.agent` | 3.1 |
| `n8n-nodes-base.code` | 2 | `@n8n/…langchain.chainLlm` | 1.9 |
| `n8n-nodes-base.executeWorkflow` | 1.3 | `@n8n/…langchain.chainRetrievalQa` | 1.7 |
| `n8n-nodes-base.executeWorkflowTrigger` | 1.1 | `@n8n/…langchain.chatTrigger` | 1.4 |
| `n8n-nodes-base.filter` | 2.3 | `@n8n/…langchain.documentDefaultDataLoader` | 1.1 |
| `n8n-nodes-base.httpRequest` | 4.4 | `@n8n/…langchain.embeddingsOpenAi` | 1.3 |
| `n8n-nodes-base.if` | 2.3 | `@n8n/…langchain.lmChatOpenAi` | 1.3 |
| `n8n-nodes-base.merge` | 3.2 | `@n8n/…langchain.memoryBufferWindow` | 1.4 |
| `n8n-nodes-base.postgres` | 2.6 | `@n8n/…langchain.outputParserStructured` | 1.3 |
| `n8n-nodes-base.removeDuplicates` | 2 | `@n8n/…langchain.retrieverVectorStore` | 1 |
| `n8n-nodes-base.respondToWebhook` | 1.5 | `@n8n/…langchain.textSplitterRecursiveCharacter` | 1 |
| `n8n-nodes-base.rssFeedRead` | 1.2 | `@n8n/…langchain.toolCalculator` | 1 |
| `n8n-nodes-base.s3` | 2 | `@n8n/…langchain.toolCode` | 1.3 |
| `n8n-nodes-base.scheduleTrigger` | 1.3 | `@n8n/…langchain.toolHttpRequest` | 1.1 |
| `n8n-nodes-base.set` | 3.4 | `@n8n/…langchain.toolWorkflow` | 2.2 |
| `n8n-nodes-base.slack` | 2.5 | `@n8n/…langchain.vectorStoreQdrant` | 1.3 |
| `n8n-nodes-base.sort` | 1 | | |
| `n8n-nodes-base.splitInBatches` | 3 | | |
| `n8n-nodes-base.splitOut` | 1 | | |
| `n8n-nodes-base.summarize` | 1.1 | | |
| `n8n-nodes-base.switch` | 3.4 | | |
| `n8n-nodes-base.wait` | 1.1 | | |
| `n8n-nodes-base.webhook` | 2.1 | | |

### Notes on major version bumps

- **`executeWorkflow` 1 → 1.3**: workflowId format changes to `__rl` resource-locator object (see section above).
- **`removeDuplicates` 1 → 2**: field configuration UI changed — review key field settings after upgrade.
- **`s3` 1 → 2**: operation parameter layout changed — verify bucket/key fields after upgrade.
- **`agent` 1.7 → 3.1**: significant AI agent rework — check tool connections and system message settings.
- **`toolWorkflow` 1.3 → 2.2**: sub-workflow invocation interface changed.

## Operational notes

- **`ENCRYPTION_KEY`** encrypts stored credentials. Set before first start — changing it later locks you out of every saved credential.
- **`OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`** keeps the main process responsive; heavy workflows run on workers.
- **Scale workers** by increasing `n8n-worker` replica count (add matching `n8n-worker-runner` replicas in lockstep).
- **Backups**: `pg_dump` the internal `yai-n8n-postgres-1` container + snapshot `./data/n8n/` (contains the encryption key file). Skip `./data/redis/` — queue state is ephemeral.
- **Restart**: `./yai.sh restart n8n` restarts all six containers.
