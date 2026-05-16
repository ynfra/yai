#!/usr/bin/env bash
# n8n.sh — sync n8n workflows between the API and n8n/workflows/
#
# Usage:
#   ./n8n.sh pull                          # download all workflows from n8n → JSON files
#   ./n8n.sh push                          # upload all JSON files → n8n (create or update by name)
#   ./n8n.sh push firecrawl_scrape.json    # push one or more specific files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WF_DIR="$SCRIPT_DIR/workflows"

if [[ -z "${YAI_N8N_URL:-}" ]]; then
  # shellcheck source=../env.sh
  source "$SCRIPT_DIR/../env.sh"
fi

API="$YAI_N8N_URL/api/v1"
AUTH_HEADER="X-N8N-API-KEY: $YAI_N8N_TOKEN"

# ── helpers ───────────────────────────────────────────────────────────────────

n8n_get()  { curl -fsSL -H "$AUTH_HEADER" "$API/$1"; }
n8n_post() { curl -fsSL -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$2" "$API/$1"; }
n8n_put()  { curl -fsSL -X PUT  -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$2" "$API/$1"; }

slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/_\+/_/g; s/^_//; s/_$//'
}

# Strip fields n8n rejects on write (binaryMode causes 400)
sanitize() {
  jq '{name, nodes, connections, settings: (.settings // {} | del(.binaryMode))}'
}

# ── pull ──────────────────────────────────────────────────────────────────────

cmd_pull() {
  local ids names wf_id wf_name fname
  local list; list=$(n8n_get "workflows?limit=100")
  local count; count=$(echo "$list" | jq '.data | length')
  echo "Pulling $count workflows from n8n …"
  echo ""

  # Build name→filename map from existing JSON files
  declare -A name_to_file
  for f in "$WF_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    local n; n=$(jq -r '.name // empty' "$f" 2>/dev/null)
    [[ -n "$n" ]] && name_to_file["$n"]="$(basename "$f")"
  done

  local created=0 updated=0
  while IFS=$'\t' read -r wf_id wf_name; do
    local wf; wf=$(n8n_get "workflows/$wf_id")

    if [[ -v name_to_file["$wf_name"] ]]; then
      fname="${name_to_file[$wf_name]}"
      echo "  [updated]  $fname"
      ((updated++)) || true
    else
      fname="$(slug "$wf_name").json"
      echo "  [new    ]  $fname"
      ((created++)) || true
    fi

    echo "$wf" | sanitize > "$WF_DIR/$fname"
  done < <(echo "$list" | jq -r '.data[] | [.id, .name] | @tsv')

  echo ""
  echo "Pull complete — $created new, $updated updated"
}

# ── push ──────────────────────────────────────────────────────────────────────

cmd_push() {
  # Collect target files
  local targets=()
  if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
      local path="$WF_DIR/$arg"
      [[ "$arg" == *.json ]] || path="$path.json"
      if [[ ! -f "$path" ]]; then
        echo "  WARN: $arg not found, skipping" >&2
        continue
      fi
      targets+=("$path")
    done
  else
    for f in "$WF_DIR"/*.json; do
      [[ -f "$f" ]] && targets+=("$f")
    done
  fi

  echo "Pushing ${#targets[@]} workflow(s) to n8n …"
  echo ""

  # Build name→id map from live n8n
  local live; live=$(n8n_get "workflows?limit=100")
  declare -A name_to_id
  while IFS=$'\t' read -r wf_id wf_name; do
    name_to_id["$wf_name"]="$wf_id"
  done < <(echo "$live" | jq -r '.data[] | [.id, .name] | @tsv')

  local created=0 updated=0
  for path in "${targets[@]}"; do
    local fname; fname="$(basename "$path")"
    local name; name=$(jq -r '.name // empty' "$path" 2>/dev/null)
    if [[ -z "$name" ]]; then
      echo "  SKIP $fname: no 'name' field" >&2
      continue
    fi

    local body; body=$(sanitize < "$path")

    if [[ -v name_to_id["$name"] ]]; then
      local wf_id="${name_to_id[$name]}"
      n8n_put "workflows/$wf_id" "$body" > /dev/null
      echo "  [updated]  $fname  (id=$wf_id)"
      ((updated++)) || true
    else
      local result; result=$(n8n_post "workflows" "$body")
      local new_id; new_id=$(echo "$result" | jq -r '.id')
      echo "  [created]  $fname  (id=$new_id)"
      ((created++)) || true
    fi
  done

  echo ""
  echo "Push complete — $created created, $updated updated"
}

# ── dispatch ──────────────────────────────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
  pull) cmd_pull ;;
  push) cmd_push "$@" ;;
  *)
    echo "Usage: $(basename "$0") pull | push [file.json ...]"
    exit 0
    ;;
esac
