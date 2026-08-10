---
description: Analyse the current conversation and update yai skills with general debugging patterns for future operators
argument-hint: ""
allowed-tools: Read, Edit, Bash, Agent
---

Act as a best-in-class Claude engineer and yai stack operator. Your goal is to
mine the current conversation for reusable operational knowledge and improve the
yai skills and slash commands so future operators (human or AI) hit fewer dead
ends.

## Workflow

### Step 1 — Mine the conversation

Read the entire conversation above this command. Extract every item that fits
one of these categories:

| Category | What to look for |
|----------|-----------------|
| **Debugging pattern** | Symptom → root cause → fix that worked |
| **Gotcha** | Non-obvious behaviour; something that would have wasted time without knowing |
| **Command recipe** | A shell incantation that was useful and not yet in any skill |
| **Operational rule** | A do/don't that is now proven by the session |

For each item, ask: *"Would this have been obvious from the existing skills?
Would it have saved meaningful time?"* Only keep the ones where the answer is
yes to both.

### Step 2 — Identify target skill files

For each extracted pattern, determine which file to update:

- Service-specific behaviour → `.claude/skills/<service>/SKILL.md`
- Docker-compose / restart / env var mechanics → `.claude/commands/yai/service/restart.md`
- Doctor output interpretation → `.claude/commands/yai/service/doctor.md`
- Stack-wide operational rules → `.claude/skills/yai/SKILL.md`
- Secret / credential hygiene → `.claude/skills/security/SKILL.md`
- Observability fan-out → `.claude/commands/yai/sre/logs.md`

Read each target file before editing it.

### Step 3 — Spawn a skill-updater agent

Collect everything you've extracted: the patterns, the target file paths, and
the current file contents. Then spawn **one Agent** with this full context and
instruct it to apply all edits. Pass it:

- The extracted patterns (written out explicitly — do not just say "the thing
  we fixed")
- The current content of each file to be updated
- The editing rules below

The agent should use the `Edit` tool for precision. It should NOT use `Write`
unless creating a brand-new file.

### Step 4 — Verify and report

After the agent finishes, read each changed file and confirm the edits are
present and coherent. Then report:

```
Updated files:
  .claude/skills/litellm/SKILL.md  — added: <one-line summary>
  .claude/commands/yai/service/restart.md  — added: <one-line summary>
  ...

Patterns captured: N
Files changed: M
```

## Editing rules (pass these to the sub-agent verbatim)

1. **General, not incident-specific.** Strip session context. Write "When X,
   do Y" — never "in this session" or "the bug we just fixed".

2. **Imperative, present tense.** Skills are read by LLM agents. Clear
   structure and concrete shell commands outperform prose.

3. **Don't duplicate.** If the pattern is already covered, skip it or add only
   the genuinely new detail.

4. **Preserve existing content.** Use `Edit` with a precise `old_string` /
   `new_string`. Never rewrite whole files.

5. **Add under a logical section heading.** If no fitting section exists,
   create one (e.g. `## Debugging`, `## Operational notes`).

6. **No noise.** Don't add disclaimers, session summaries, or meta-commentary
   inside the skill files themselves. Skills are reference material, not
   narratives.

7. **Never touch `.env` or `.env.local` files.**

## Don'ts

- Don't update skills with things already well-covered.
- Don't create new skill files for topics that belong in an existing one.
- Don't capture ephemeral state (specific container IDs, timestamps, log
  lines). Only generalised patterns survive.
- Don't annotate skills with "added by /yai:feedback" — skills should read as
  if they were always there.
