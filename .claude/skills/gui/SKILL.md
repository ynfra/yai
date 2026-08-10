---
name: gui
description: How to control every yai web UI — login recipes, navigation patterns, and common actions for Grafana, Langfuse, MinIO, n8n, Windmill, LiteLLM, Qdrant, and Traefik. Auto-load when asked to log in, navigate, click, or perform any action in a yai service UI.
when_to_use: Load when the user asks how to log into any yai service UI, navigate to a specific page, perform an action in the browser, or needs step-by-step UI instructions for Grafana, Langfuse, MinIO, n8n, Windmill, LiteLLM, Qdrant, or Traefik.
allowed-tools: Bash(agent-browser *)
---

# yai GUI control

All interaction is done via the `agent-browser` CLI (see `agent-browser` skill for
the full command reference). Core loop: open → snapshot -i → fill/click → snapshot.

## Credentials (from SOUL.md)

| Service   | URL                       | Username            | Password     |
|-----------|---------------------------|---------------------|--------------|
| Grafana   | http://localhost:22000    | `admin`             | `Admin1234!` |
| Langfuse  | http://localhost:23000    | `admin@ynfra.org` | `Admin1234!` |
| MinIO     | http://localhost:25001    | `admin`             | `Admin1234!` |
| n8n       | http://localhost:26002    | `admin@ynfra.org` | `Admin1234!` |
| Windmill  | http://localhost:28000    | `admin@ynfra.org` | `Admin1234!` |
| LiteLLM   | http://localhost:24000/ui | `admin`             | `LITELLM_MASTER_KEY` from `litellm/.env` |
| Qdrant    | http://localhost:26000    | —                   | (no auth)    |
| Traefik   | http://localhost:27001    | —                   | (no auth)    |

---

## Grafana

### Login
```bash
agent-browser open http://localhost:22000
agent-browser snapshot -i
agent-browser fill @e5 admin
agent-browser fill @e6 "Admin1234!"
agent-browser click @e3          # Log in button
agent-browser wait --url "**/home"
agent-browser snapshot -i
```

### Common actions
```bash
# List dashboards
agent-browser open "http://localhost:22000/dashboards"

# Open a specific dashboard by title — click its link in the snapshot
agent-browser snapshot -i
agent-browser click @eN

# Explore (ad-hoc query)
agent-browser open "http://localhost:22000/explore"

# Data sources
agent-browser open "http://localhost:22000/connections/datasources"
```

---

## Langfuse

### Login
```bash
agent-browser open http://localhost:23000/auth/sign-in
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser fill @eN "admin@ynfra.org"   # email field
agent-browser fill @eN "Admin1234!"          # password field
agent-browser click @eN                      # Sign in button
agent-browser wait --url "**/projects"
agent-browser snapshot -i
```

### Common actions
```bash
# Traces
agent-browser open "http://localhost:23000/project/<project-id>/traces"

# Prompt management
agent-browser open "http://localhost:23000/project/<project-id>/prompts"

# Evals
agent-browser open "http://localhost:23000/project/<project-id>/evals"

# API keys (project settings)
agent-browser open "http://localhost:23000/project/<project-id>/settings"
```

---

## MinIO

### Login
```bash
agent-browser open http://localhost:25001
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser fill @eN admin
agent-browser fill @eN "Admin1234!"
agent-browser click @eN              # Login button
agent-browser wait --url "**/browser"
agent-browser snapshot -i
```

### Common actions
```bash
# Browse buckets
agent-browser open "http://localhost:25001/browser"

# Create bucket — click "+ Create Bucket" in the UI after opening the browser page

# Object upload — navigate into a bucket, use the upload button
```

---

## n8n

### Login
```bash
agent-browser open http://localhost:26002/signin
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser fill @eN "admin@ynfra.org"
agent-browser fill @eN "Admin1234!"
agent-browser click @eN              # Sign in button
agent-browser wait --url "**/workflows"
agent-browser snapshot -i
```

### Common actions
```bash
# Workflows list
agent-browser open "http://localhost:26002/home/workflows"

# Create new workflow
agent-browser open "http://localhost:26002/workflow/new"

# Credentials
agent-browser open "http://localhost:26002/home/credentials"

# Executions log
agent-browser open "http://localhost:26002/home/executions"
```

---

## Windmill

### Login
```bash
agent-browser open http://localhost:28000
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser fill @eN "admin@ynfra.org"
agent-browser fill @eN "Admin1234!"
agent-browser click @eN              # Login button
agent-browser wait --url "**/scripts"
agent-browser snapshot -i
```

### Common actions
```bash
# Scripts
agent-browser open "http://localhost:28000/scripts"

# Flows
agent-browser open "http://localhost:28000/flows"

# Variables / secrets
agent-browser open "http://localhost:28000/variables"

# Resources (connections)
agent-browser open "http://localhost:28000/resources"

# Audit log
agent-browser open "http://localhost:28000/audit_logs"
```

---

## LiteLLM

### Login
```bash
agent-browser open "http://localhost:24000/ui"
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser fill @eN admin
agent-browser fill @eN "Admin1234!"
agent-browser click @eN              # Login button
agent-browser wait --url "**/?userID=*"
agent-browser snapshot -i
```

### Common actions
```bash
# Models tab — see configured model list
agent-browser open "http://localhost:24000/ui"
# click "Models" in sidebar after login

# Virtual keys
# click "API Keys" in sidebar

# Usage / spend dashboard
# click "Usage" in sidebar
```

---

## Qdrant

No authentication required.

```bash
agent-browser open "http://localhost:26000/dashboard"
agent-browser wait --load networkidle
agent-browser snapshot -i
# Collections are listed in the sidebar
```

---

## Traefik

No authentication required.

```bash
agent-browser open "http://localhost:27001/dashboard/"
agent-browser wait --load networkidle
agent-browser snapshot -i
# HTTP routers / services / middlewares listed in the UI
```

---

## Tips

- **Refs go stale** after every navigation or form submit — always re-run
  `agent-browser snapshot -i` before the next action.
- **Find the right ref**: if a field is not at the expected number, use
  `agent-browser snapshot -i` and scan for label text near the input.
- **Shadow DOM / iframes**: if `-i` shows nothing useful, try
  `agent-browser snapshot` (no flag) to see the full tree.
- **Slow SPAs**: add `agent-browser wait --load networkidle` after `open`
  before snapshotting.
- **Multi-tab interference**: agent-browser shares a single browser session.
  Close unused tabs with `agent-browser close` between unrelated tasks.
