# Candidate AI workflows — batch 1 (to test before adoption)

These 4 `cand_*.json` workflows are imported-but-unverified adaptations of popular
public n8n AI templates, re-pointed at yai services. They are deliberately
**additive** — none duplicate an existing `[Demo]` workflow. Prefix `cand_` marks
them as the trial batch; delete the files to drop them.

All four follow existing yai conventions:

- **LLM** → `lmChatOpenAi` (`openrouter/openai/gpt-oss-120b:free`) on the
  `yai-litellm` credential (LiteLLM `:24000`).
- **Embeddings** → `embeddingsOpenAi` on `yai-litellm` (default model, same as the
  existing `[Demo] RAG` workflows — see caveat below).
- **Vector store** → native `vectorStoreQdrant` on the `yai-qdrant` credential.
- **Memory / state / tables** → Postgres on `yai-postgres-nette`.
- **Scraping** → Firecrawl HTTP API at `http://host.docker.internal:21000`.
- **Notifications** → Slack on `yai-slack`.
- **Tracing** → Langfuse, automatic via the LiteLLM success callback (no node).

## How to import

```bash
# UI: n8n editor (http://localhost:26002) → Workflows → Import from File
# or via CLI inside the container:
docker exec -i yai-n8n n8n import:workflow --input=/path/in/container.json
```

| File | Source template(s) | Trigger | yai services exercised | New tech? | Complexity |
|---|---|---|---|---|---|
| `cand_lead_enrichment_research.json` | n8n #6776 / Ops B4 — Company research & lead enrichment | Manual | Firecrawl, **Information Extractor** + LiteLLM, Postgres | none | Low–Med |
| `cand_page_change_monitor.json` | Firecrawl roundup #9 — competitor/page-change monitor | Schedule (24h) | Firecrawl, LiteLLM (diff), Postgres, Slack | none | Low–Med |
| `cand_reasoning_agent.json` | Agent #9 — multi-step reasoning with thinking tools | Manual | LiteLLM, Postgres-style memory, Langfuse | none | Low–Med |
| `cand_website_chat_rag_ingest.json` | RAG #2 — turn any website into a chatbot (ingest half) | Manual | **Firecrawl map+scrape**, Qdrant, LiteLLM embeddings | none | Med |

---

## 1. `cand_lead_enrichment_research.json`
**What:** Given a company name, Firecrawl `/search` finds its site, `/scrape`
pulls the markdown, the **Information Extractor** node (new node type for this
stack) returns structured firmographics, and a row lands in a `lead_enrichment`
Postgres table (auto-created).
**Test:** Run with the default `Nette Foundation`; check the `lead_enrichment`
table for a populated row.
**Watch-outs:** Information Extractor relies on the model returning valid JSON —
`gpt-oss-120b:free` usually does, but bump to a stronger model if extraction is
flaky. `queryReplacement` order must match the `INSERT` column order.

## 2. `cand_page_change_monitor.json`
**What:** Daily schedule scrapes a target URL, compares against the last snapshot
in a `page_snapshots` table, and on change asks LiteLLM to summarise the diff,
then posts to Slack and stores the new snapshot.
**Test:** Lower the schedule or run manually twice (edit the target page content
between runs, or point at a frequently-updated page).
**Watch-outs:** **First run posts one baseline alert** (no previous snapshot to
compare) — expected. Set the real Slack channel in `Set Target`. Only stores a
snapshot when a change is detected, so the table stays small.

## 3. `cand_reasoning_agent.json`
**What:** An agent forced to plan-then-act: it must call a `plan` tool first, use
the `calculator` for all arithmetic, and reference intermediate results in the
final answer. Fully self-contained (no external SaaS) — the cleanest **Langfuse
trace showcase** since every tool hop is captured via the LiteLLM callback.
**Test:** Run with the default multi-part throughput question; verify it plans,
calls the calculator, and the trace appears in Langfuse (`:23000`).
**Watch-outs:** Uses window-buffer memory keyed by `session_id`; swap to a
`Postgres Chat Memory` node if you want persistence across executions.

## 4. `cand_website_chat_rag_ingest.json`
**What:** The genuinely-new ingest pattern — Firecrawl `/map` enumerates a whole
site, the first N pages are scraped and embedded into a dedicated Qdrant
collection `website_chat`. (Existing `[Demo] RAG Ingest` only handles a single
URL.)
**Test:** Run with the default `https://docs.n8n.io` (capped at 10 pages); then
query it by pointing the existing `[Demo] RAG Query` workflow's Qdrant collection
at `website_chat`.
**Watch-outs:** `/map` response shape can be `links` or `data.links` depending on
Firecrawl version — the `Expand URLs` node handles both. Raise `max_pages`
carefully (each page is a scrape call).

---

## ⚠️ Stack caveat surfaced by the research (applies to RAG / extraction)

`litellm/config.yml` currently only routes `openrouter/*` (chat). The
`embeddingsOpenAi` node sends OpenAI's default embedding model name, which
**won't match the `openrouter/*` route** unless an embeddings model is added to
LiteLLM. The existing `[Demo] RAG` workflows have the same dependency — if they
work today, #4's website ingest will too. If embeddings 404, add an embeddings
model to `litellm/config.yml` (the one minimal config change worth making for the
whole RAG category). Left as-is per the "minimal changes" decision; flagged here
as a TODO.
