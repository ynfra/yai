---
description: Debug a broken Grafana dashboard on the yai stack — static lint + live query probes
argument-hint: <dashboard UID | title> [symptom]
allowed-tools: Read, Bash
---

Act as a senior Grafana / observability engineer on the yai AI stack.
Goal: locate the named dashboard, lint the JSON, probe the live
datasources for each panel target, and report a root cause with the
exact fix.

User input: $ARGUMENTS

## Inputs

- A dashboard UID, title, or partial title.
- A symptom: "No data", "Datasource not found", wrong values, broken
  variable, etc.
- Optionally a specific panel/query.

If only a dashboard reference was given, run both the static lint and
the live probe and report all anomalies.

## Workflow

1. **Bootstrap.** `source ./env.sh`. The `grafana`, `vmetrics`, `vlogs`,
   `vtraces` skills carry datasource conventions and query-language
   gotchas.

2. **Locate the dashboard.** Use the Grafana API:
   ```sh
   H="Authorization: Bearer $YAI_GRAFANA_TOKEN"
   curl -s -H "$H" "$YAI_GRAFANA_URL/api/search?type=dash-db" \
     | jq '.[] | {uid, title, folderTitle}'
   curl -s -H "$H" "$YAI_GRAFANA_URL/api/dashboards/uid/<UID>" | jq
   ```

3. **Static lint:**
   - **JSON parses.** `jq . <file> > /dev/null`.
   - **No duplicate panel IDs.**
     ```
     jq '[.. | objects | select(has("id") and has("type")) | .id] | group_by(.) | map(select(length>1))' <dashboard.json>
     ```
   - **Every target has an expr/query and refId.**
   - **Template variables use `:pipe` for multi-select regex filters.**
   - **Datasource UIDs exist.** Cross-check against
     `curl -s -H "$H" "$YAI_GRAFANA_URL/api/datasources"`.

4. **Live probe** (for "No data" or datasource issues):
   - For each PromQL target, probe VictoriaMetrics:
     ```sh
     curl -sG "$YAI_VMETRICS_URL/api/v1/query" \
       --data-urlencode "query=$EXPR" | jq '.status, (.data.result | length)'
     ```
   - For LogsQL targets, probe VictoriaLogs (see `vlogs` skill).
   - For trace targets, probe VictoriaTraces Jaeger API (see `vtraces` skill).
   - If connection refused, report once and stop probing that backend.

5. **Synthesise.** One root cause + the exact JSON edit or config change.

## Output format

```
dashboard: <title>  uid: <uid>

Static lint:
  [PASS] JSON parses
  [FAIL] Panel ID 12 appears 3 times — deduplicate
  ...

Live probe (per panel target):
  [panel "Requests/s" / refId A]  vm: OK (5 series)
  [panel "Errors" / refId B]      vm: NO DATA — metric 'litellm_errors_total' does not exist
    → check: curl ... /api/v1/label/__name__/values | grep litellm

Root cause: <single sentence>
Fix: <exact change — file + line or JSON diff>
```

## Don'ts

- Don't pre-escape `${` to `$${` — Grafana JSON uses raw `${var}`.
- Don't loop on connection failures.
- Don't write to any data source during live probes. Read-only.
