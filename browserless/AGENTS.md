# browserless — headless Chromium as a service

Browserless v2 exposes a managed pool of headless Chromium instances behind
an HTTP + WebSocket API. Connect to it from Puppeteer / Playwright / raw CDP
clients to run scraping jobs, render PDFs, take screenshots, or evaluate
arbitrary page scripts without managing browser processes yourself.

This is the **generic Chromium-as-a-service endpoint** for the yai stack —
the workhorse that Firecrawl, n8n workflows, ad-hoc Playwright scripts and
any "give me a browser" consumer can share. Pair with a queue / scheduler
upstream; Browserless itself is intentionally stateless.

## Image

- `ghcr.io/browserless/chromium:latest` — Browserless v2, the actively
  maintained line. Published on GHCR (not Docker Hub).
- **Do not use `browserless/chrome`** — that is Browserless v1, legacy,
  receives no further updates, and has a different API surface.
- Tag policy: `latest` is fine for an internal stack; pin to a specific
  release tag (e.g. `v2.x.y`) once you depend on a particular API shape.
  Set `BROWSERLESS_VERSION` in `.env` to override.

## Ports

| Host  | Container | Purpose                                          |
|-------|-----------|--------------------------------------------------|
| 26003 | 3000      | HTTP REST API + WebSocket CDP endpoint (shared)  |

The same port handles both REST (`/function`, `/pdf`, `/screenshot`, …) and
WebSocket upgrades (`/?token=…`, `/playwright`, `/chromium/playwright`, …).

## Persistence

**Stateless.** No `./data/` directory, no bind mount. Each session is
ephemeral and dies with its tab. If you need to persist cookies / storage
between runs, manage that in the caller (e.g. Puppeteer `userDataDir`
streamed back, or persist via your own DB).

`yai.sh init browserless` is a no-op for this service (see the
`browserless) ;;` case in `../yai.sh`).

## First-time setup

```bash
# 1. Generate a strong token and put it in .env (replace change_me)
openssl rand -hex 32
$EDITOR .env                  # set BROWSERLESS_TOKEN

# 2. Start the service
../yai.sh start browserless

# 3. Smoke-test
curl "http://localhost:26003/pressure?token=$BROWSERLESS_TOKEN"
# → {"pressure":{"date":...,"reason":"","message":"","isAvailable":true,...}}
```

**Do not expose port 26003 to the public internet without a token.**
Browserless will happily execute arbitrary JS in a real browser — an
unauthenticated endpoint is remote code execution as a service.

## Docs & references

- Browserless docs (v2): <https://docs.browserless.io/>
- GitHub: <https://github.com/browserless/browserless>
- Image on GHCR: <https://github.com/browserless/browserless/pkgs/container/chromium>
- REST API reference: <https://docs.browserless.io/baas/start>
- WebSocket / CDP usage: <https://docs.browserless.io/baas/libraries-and-frameworks/libraries>
- Environment variables: <https://docs.browserless.io/baas/configuration>

## Operational notes

### Auth

Every request must carry `?token=<BROWSERLESS_TOKEN>`:

```bash
# REST
curl -X POST "http://localhost:26003/screenshot?token=$BROWSERLESS_TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{"url":"https://example.com"}' --output out.png

# WebSocket (Puppeteer)
const browser = await puppeteer.connect({
  browserWSEndpoint: `ws://localhost:26003?token=${process.env.BROWSERLESS_TOKEN}`,
});

# WebSocket (Playwright)
const browser = await chromium.connect(
  `ws://localhost:26003/playwright/chromium?token=${process.env.BROWSERLESS_TOKEN}`,
);
```

### Useful REST endpoints

- `GET  /pressure`     — health + load signal (used by the healthcheck)
- `POST /function`     — run an arbitrary `module.exports = async ({ page }) => …`
- `POST /pdf`          — render a URL or HTML body to PDF
- `POST /screenshot`   — capture PNG / JPEG of a URL or HTML body
- `POST /content`      — return final rendered HTML
- `POST /scrape`       — selector-based scraping
- `GET  /sessions`     — list live sessions (debug)
- `GET  /metrics`      — Prometheus-style metrics

### Sizing

- `CONCURRENT` (default `3`) caps simultaneous Chromium sessions. Each tab
  under real load is 150–300 MB RAM; size for the host.
- `MAX_QUEUE_LENGTH` (default `10`) is how many requests are held when
  saturated; beyond that, callers get HTTP 429.
- `TIMEOUT` (default `30000` ms) hard-kills any session that exceeds it.

### Healthcheck

The healthcheck hits `/pressure?token=…` and trusts a 200 response.
`/pressure` also reports `isAvailable`, queue depth and CPU/mem pressure
— scrape it from your monitoring stack if you want autoscaling signals.

## Relationship to agent-browser (Claude Code skill)

The [agent-browser](https://github.com/vercel-labs/agent-browser) skill
(installed on the host via `npx skills add vercel-labs/agent-browser`) is the
**canonical control plane for AI agents driving a browser** in this repo. It
runs as a long-lived daemon, exposes a dashboard, and surfaces a snapshot /
ref-based API designed for LLM tool calls — agents reference DOM nodes by
`@ref` rather than dealing with raw selectors or coordinates.

`browserless/` (this service) is the **generic Chromium-as-a-service
endpoint** — a stateless pool aimed at scripts and pipelines that already
know how to drive a browser: Firecrawl workers, n8n HTTP nodes, ad-hoc
Playwright scrapers, PDF/screenshot generators, CI smoke tests.

Rule of thumb:

- **Agent driving the browser interactively, needs a snapshot/ref model
  and a UI?** → `agent-browser` skill.
- **Pipeline / script / service that just needs "give me a Chromium and
  let me write Puppeteer/Playwright/CDP against it"?** → `browserless`.
