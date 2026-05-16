---
name: browserless
description: Browserless headless Chromium service on the yai stack — REST endpoints (screenshot, PDF, scrape, function), WebSocket CDP/Puppeteer/Playwright patterns, token auth, sizing. Auto-load on Browserless, headless browser, Puppeteer, Playwright, CDP, screenshot, PDF, scrape-script questions.
when_to_use: Load when the user wants to take a screenshot, generate a PDF, scrape HTML, or run a Puppeteer/Playwright script against a URL without using agent-browser interactively. Also load when an n8n or Windmill workflow needs headless browser automation.
allowed-tools: Bash(curl *)
---

# Browserless

Managed pool of headless Chromium instances. URL: `YAI_BROWSERLESS_URL` (port 26003).
Same port handles both REST and WebSocket (CDP/Playwright) connections.

> **Use `agent-browser` skill for LLM-driven interactive sessions** (snapshot/ref model,
> stateful daemon). Use `browserless` for scripts and pipelines that drive Chromium
> directly via Puppeteer, Playwright, or CDP.

Token: `BROWSERLESS_TOKEN` in `browserless/.env`.

## Auth

Every request requires `?token=<BROWSERLESS_TOKEN>`:

```sh
source ./env.sh
BL_TOKEN=$(grep BROWSERLESS_TOKEN browserless/.env | cut -d= -f2)

# Health / load signal
curl -s "$YAI_BROWSERLESS_URL/pressure?token=$BL_TOKEN" | jq '{isAvailable, reason}'
```

## REST endpoints

```sh
# Screenshot (PNG)
curl -s -X POST "$YAI_BROWSERLESS_URL/screenshot?token=$BL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}' --output screenshot.png

# PDF render
curl -s -X POST "$YAI_BROWSERLESS_URL/pdf?token=$BL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}' --output page.pdf

# Rendered HTML (after JS execution)
curl -s -X POST "$YAI_BROWSERLESS_URL/content?token=$BL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}' | jq -r '.data' | head -50

# Selector-based scrape
curl -s -X POST "$YAI_BROWSERLESS_URL/scrape?token=$BL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "url": "https://example.com",
    "elements": [{"selector": "h1"}, {"selector": "p"}]
  }' | jq '.data[].results[].text'

# Arbitrary function (Puppeteer page object)
curl -s -X POST "$YAI_BROWSERLESS_URL/function?token=$BL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "code": "module.exports = async ({ page }) => { await page.goto(\"https://example.com\"); return { title: await page.title() }; }"
  }' | jq
```

## WebSocket — Puppeteer

```js
const puppeteer = require('puppeteer-core');
const browser = await puppeteer.connect({
  browserWSEndpoint: `ws://localhost:26003?token=${process.env.BROWSERLESS_TOKEN}`,
});
const page = await browser.newPage();
await page.goto('https://example.com');
console.log(await page.title());
await browser.disconnect();
```

## WebSocket — Playwright

```js
const { chromium } = require('playwright-core');
const browser = await chromium.connect(
  `ws://localhost:26003/playwright/chromium?token=${process.env.BROWSERLESS_TOKEN}`
);
const page = await browser.newPage();
await page.goto('https://example.com');
await browser.close();
```

## Useful monitoring endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /pressure?token=…` | Health + load signal (`isAvailable`, queue depth, CPU/mem) |
| `GET /sessions?token=…` | Live active sessions (debug) |
| `GET /metrics?token=…` | Prometheus-style metrics |

## Sizing knobs (`.env`)

| Variable | Default | Effect |
|----------|---------|--------|
| `CONCURRENT` | 3 | Max simultaneous Chromium sessions |
| `MAX_QUEUE_LENGTH` | 10 | Queued requests when saturated; beyond this = HTTP 429 |
| `TIMEOUT` | 30000 ms | Hard-kill any session exceeding this duration |

Each live tab under real load uses 150–300 MB RAM. Size `CONCURRENT` for the host.

## Operational notes

- **v2 only** — the image is `ghcr.io/browserless/chromium`. Do not use `browserless/chrome` (v1, legacy, different API).
- **Stateless** — no `./data/` directory. Cookies/storage don't survive between sessions unless managed in the caller.
- **No public exposure** — an unauthenticated Browserless endpoint is effectively remote code execution as a service.
