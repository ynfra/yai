---
description: Run the yai stack doctor and interpret all findings
argument-hint: ""
allowed-tools: Read, Bash
---

Act as a senior operator managing the yai self-hosted AI stack. Goal:
run the full `yai doctor` check, interpret every finding, and produce a
ranked action list.

User input: $ARGUMENTS

## Workflow

1. **Run doctor.**
   ```sh
   ./yai.sh doctor
   ```

2. **Interpret each category:**

   **Toolchain checks** — docker CLI, docker daemon, docker compose,
   docker group membership, claude CLI. Flag any FAIL as blocking; WARN
   as non-blocking.

   **Service table** — for each service:
   - **STATE** (`UP`/`down`/`PARTIAL`) — container running status.
   - **.ENV** (`env`/`env+loc`/`none`) — whether `.env` and/or `.env.local` exist. `none` means neither file is present; the service cannot start.
   - **DATA** (`OK`/`WARN`/`n/a`) — `WARN` means a required data
     directory is missing. Fix: `./yai.sh init <service>`.
   - **COMPOSE** (`OK`/`FAIL`) — `docker compose config` failed, meaning
     the compose file is broken or an env var is missing.

3. **Rank findings.**
   - FAIL → blocking (fix before starting anything)
   - .ENV=none → no `.env` file present; create it from the template in the service folder, then do a full `./yai.sh stop <svc> && ./yai.sh start <svc>`.
   - DATA=WARN → run `./yai.sh init <service>` to create the directories
   - PARTIAL → check logs (`./yai.sh logs <service>`)

## Output format

```
Toolchain: <OK / N issues>

Services with issues:
  <service>  STATE=<down>  .ENV=<none>  →  create <service>/.env
  <service>  STATE=<PARTIAL>              →  check logs: ./yai.sh logs <svc>
  ...

Ranked action list:
  1. [BLOCKING]  <action>
  2. [MUST-FIX]  <action>
  3. [SHOULD-FIX] <action>

Overall: <GREEN / YELLOW / RED>
```

## Don'ts

- Don't rotate secrets — surface the paths and instructions, let the user
  edit.
- Don't start or stop services — report, don't act.
