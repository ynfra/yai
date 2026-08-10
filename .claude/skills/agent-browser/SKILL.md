---
name: agent-browser
description: agent-browser CLI — headless Chromium for AI agents. Snapshot-and-ref workflow, core commands, and yai service interaction patterns. Auto-load when asked to open a browser, navigate a URL, click, fill, screenshot, or interact with any yai web UI (Grafana, n8n, Windmill, Langfuse, MinIO, etc.).
when_to_use: Load when the task involves navigating a live web page, clicking UI elements, filling forms, or taking a screenshot during an agentic workflow. This is the right tool for interactive reasoning over a browser — use firecrawl for batch scraping and browserless for scripted automation.
allowed-tools: Bash(agent-browser *)
---

# agent-browser

Host-native headless Chromium CLI (`agent-browser` binary on PATH). No Docker.
Produces compact accessibility-tree snapshots with short `@eN` refs so agents
can interact with pages in ~200–400 tokens instead of parsing HTML.

Install once:
```bash
npm install -g agent-browser && agent-browser install
```

## Core loop

```bash
agent-browser open <url>     # 1. navigate
agent-browser snapshot -i    # 2. see interactive elements + refs
agent-browser fill @e3 text  # 3. act on a ref
agent-browser snapshot -i    # 4. re-snapshot after every page change
```

**Refs go stale on every page change** (navigation, form submit, dialog open).
Always re-snapshot before using refs again.

## Key commands

```bash
# Navigation
agent-browser open <url>
agent-browser get url
agent-browser get title
agent-browser close          # close current tab

# Reading
agent-browser snapshot -i            # interactive elements only (preferred)
agent-browser snapshot -i -u         # include href URLs
agent-browser snapshot -i -c         # compact (no empty nodes)
agent-browser snapshot -s "#main"    # scope to a CSS selector
agent-browser get text @e5           # extract text from a ref

# Interacting
agent-browser click @e3
agent-browser fill @e3 "value"       # clear + type
agent-browser type @e3 "value"       # type without clearing
agent-browser press Enter
agent-browser select @e4 "Option"    # <select> dropdown
agent-browser check @e5              # checkbox
agent-browser hover @e6

# Viewport / device
agent-browser set viewport 1920 1080        # 1920×1080 (default is narrower)
agent-browser set viewport 1920 1080 2      # 2× retina (same CSS size, sharper PNG)
agent-browser set device "iPhone 14"        # mobile emulation

# Waiting
agent-browser wait --load networkidle
agent-browser wait --url "**/dashboard"
agent-browser wait --text "Success"

# Output
agent-browser screenshot /path/out.png       # viewport-height crop
agent-browser screenshot --full /path/full.png  # full scroll height
agent-browser pdf /path/out.pdf
```

## yai service URLs

| Service | URL |
|---------|-----|
| Grafana | http://localhost:22000 |
| n8n | http://localhost:26002 |
| Windmill | http://localhost:28000 |
| Langfuse | http://localhost:23000 |
| MinIO console | http://localhost:25001 |
| LiteLLM | http://localhost:24000 |
| Qdrant | http://localhost:26000 |
| vmetrics targets | http://localhost:28428/targets |

All credentials are in `env.sh` — `source ./env.sh` before scripting.

## Common patterns

### Grafana login
```bash
agent-browser open http://localhost:22000
agent-browser snapshot -i
agent-browser fill @e5 admin          # username field
agent-browser fill @e6 "Admin1234!"   # password field
agent-browser click @e3           # Log in button
agent-browser snapshot -i         # verify redirect to home
```

### Navigate to a Grafana dashboard
```bash
# After login
agent-browser open "http://localhost:22000/dashboards"
agent-browser snapshot -i
# Find the dashboard link ref, then:
agent-browser click @eN
```

### Screenshot a page for inspection
```bash
agent-browser open http://localhost:22000
agent-browser wait --load networkidle
agent-browser screenshot --full /tmp/grafana.png
agent-browser close
```

### Take 1920px documentation screenshots of all yai services
```bash
# Set viewport once per session — persists across navigations
agent-browser set viewport 1920 1080

# No-auth services
agent-browser open http://localhost:26000/dashboard
agent-browser wait --load networkidle
agent-browser screenshot --full qdrant/docs/assets/ui.png

# Grafana dashboards (logged in) — panels render asynchronously
# Use viewport screenshot (NOT --full) after a 20s wait; --full captures before panels load
agent-browser open "http://localhost:22000/d/infra-overview?from=now-24h&to=now&orgId=1"
agent-browser wait --load networkidle
sleep 20
agent-browser screenshot grafana/docs/assets/grafana-infra-overview.png
```

### MinIO login and screenshot
```bash
agent-browser open http://localhost:25001
agent-browser wait --load networkidle
agent-browser snapshot -i -c   # find Username / Password refs
agent-browser fill @e6 "admin"
agent-browser fill @e7 "Admin1234!"
agent-browser click @e2        # Login button
agent-browser wait --load networkidle
agent-browser screenshot --full minio/docs/assets/ui.png
```

### LiteLLM login and screenshot
```bash
agent-browser open http://localhost:24000/ui
agent-browser wait --load networkidle
agent-browser snapshot -i -c
agent-browser fill @e4 "admin"
agent-browser fill @e8 "Admin1234!"
agent-browser click @e6   # Login button
agent-browser wait --load networkidle
agent-browser screenshot --full litellm/docs/assets/ui.png
```

## Troubleshooting

- **Ref not found**: re-snapshot — refs go stale after any page change.
- **Nothing interactive in snapshot**: try `agent-browser snapshot` (no `-i`)
  to see the full tree; the target may be inside a shadow DOM or iframe.
- **Page not loading**: add `agent-browser wait --load networkidle` after `open`.
- **Daemon not running**: `agent-browser install` registers the background daemon;
  run once after install or reboot.
