---
description: Show container status across yai services and interpret health
argument-hint: [service | all]
allowed-tools: Read, Bash
---

Act as a senior operator managing the yai self-hosted AI stack. Goal:
show container status for all (or one) yai service(s), interpret what's
running vs. stopped vs. degraded, and flag anything that needs attention.

User input: $ARGUMENTS

## Inputs

- **`[service]`** — optional. A single service name from the `yai` skill's
  service table. Defaults to `all`.

## Workflow

1. **Get container status.**
   ```sh
   ./yai.sh ps all
   # For one service:
   ./yai.sh ps <service>
   # Or with exit codes for stopped containers:
   ./yai.sh doctor
   ```

2. **Classify each service.**
   - **Running** — all containers in the compose project are `running`.
   - **Partial** — some containers up, some down (often a dependency
     failure or a worker that exited after completing a task).
   - **Stopped** — all containers exited or absent.
   - **Restarting** — container is in a crash loop (check logs).

3. **Flag issues.** For any non-running service, note the likely cause:
   - Dependency not started (e.g. `litellm` needs `postgres` up first)
   - Missing `.env` file (check with `./yai.sh doctor`)
   - Port conflict
   - Data directory missing (run `./yai.sh init <service>`)

## Output format

```
SERVICE          STATE     CONTAINERS
grafana          running   5/5
litellm          stopped   0/1  (postgres must be running first)
n8n              partial   3/4  (worker container exited — check logs)
...

Summary: <N> running, <N> partial, <N> stopped

Action items:
  1. <service>: <what to do>
```

## Don'ts

- Don't restart services automatically — report findings, let the user
  decide.
- Don't delete data directories or containers — only surface the issue.
