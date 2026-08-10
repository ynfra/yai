---
name: security
description: Security rules for the yai stack — never read .env/.env.local, never commit secrets, never overwrite .env files, credential hygiene. Auto-load on .env, .env.local, secret, credential, API key, password, token, encryption key questions.
when_to_use: Load whenever the user asks about .env files, secrets, passwords, API keys, credential rotation, or any action that might expose or modify sensitive configuration. Also load before any git operation that touches .env files, or when the user wants to add a new secret to the stack.
---

# Security

## Hard rules — no exceptions

**Never read `.env` or `.env.local` files.**
These files may contain real passwords, API keys, and encryption keys.
Use `source ./env.sh` instead — it exports all credentials as env vars and is the canonical interface.

```sh
# Correct: use env.sh
source ./env.sh
curl -H "Authorization: Bearer $YAI_LITELLM_MASTER_KEY" "$YAI_LITELLM_URL/v1/models"

# WRONG: never do this
cat litellm/.env
cat litellm/.env.local
```

**Never overwrite `.env` files.**
When a compose file needs a new variable, append it to `.env` with a comment. Never reorganise or regenerate the file — this overwrites secrets the user has set.

```sh
# Correct: append only
echo "" >> service/.env
echo "# Added for feature X" >> service/.env
echo "NEW_VAR=change_me" >> service/.env
```

**Never commit real secrets to public repos.**
`.env` files are tracked in git and hold real secrets after setup — do not push this repo to a public remote without scrubbing secrets first.
`.env.local` is gitignored and is an optional override layer. Do not `git add` it.

**Never hardcode credentials in commands or files.**
Always reference env vars (`$YAI_LITELLM_MASTER_KEY`, `$YAI_POSTGRES_PASSWORD`, etc.) sourced from `env.sh`.

**Never paste secrets into external systems.**
Don't put tokens, passwords, or API keys into prompts sent to external LLMs, webhook payloads, log queries, or dashboards.

## Secret layout

| File | Contains | Tracked in git |
|------|----------|---------------|
| `<service>/.env` | Real secrets (baked in at setup time) | Yes — do not commit to public repos |
| `<service>/.env.local` | Optional personal overrides (gitignored) | No |
| `env.sh` | Assembles URLs + re-exports creds via env vars | Yes |

Real secrets live in `.env`. `.env.local` is an optional override layer for local tweaks; it is gitignored and loaded after `.env` by `yai.sh`.

## `./yai.sh doctor` output

The `.ENV` column shows whether config files exist for each service:
- `env` — only `.env` present (normal)
- `env+loc` — both `.env` and `.env.local` present
- `none` — neither file exists; the service cannot start. Fix: create `<service>/.env` from the template, then run `./yai.sh stop <svc> && ./yai.sh start <svc>`.

## Generating secrets

```sh
openssl rand -hex 32      # 64-char hex — good for ENCRYPTION_KEY, MASTER_KEY, tokens
openssl rand -base64 32   # 44-char base64 — good for passwords
```

Store the output in the relevant `<service>/.env` entry (or in `<service>/.env.local` for a local-only override).
