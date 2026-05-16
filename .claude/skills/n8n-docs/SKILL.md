---
name: n8n-docs
description: n8n node reference — core nodes, app/action nodes, AI cluster nodes (agents, LLMs, memory, tools, vector stores). Node parameters, operations, and doc links. Auto-load on questions about specific n8n node types, parameters, AI agent setup, LLM nodes, RAG chains, or "which node should I use for X".
when_to_use: Load when the user asks which n8n node to use for a specific task, how to configure a node's parameters, or how to build an AI agent, RAG chain, or LLM workflow in n8n. Also load when troubleshooting a specific node type's behavior.
---

# n8n Node Documentation Reference

Official docs root: https://docs.n8n.io/integrations/builtin/node-types/

---

## Core Nodes

Full list: https://docs.n8n.io/integrations/builtin/core-nodes/

### Triggers
| Node | Doc path | Notes |
|---|---|---|
| Manual Trigger | `core-nodes/n8n-nodes-base.manualTrigger` | Start by hand |
| Schedule Trigger | `core-nodes/n8n-nodes-base.scheduleTrigger` | Cron or interval |
| Webhook | `core-nodes/n8n-nodes-base.webhook` | HTTP POST/GET receiver |
| Email Trigger (IMAP) | `core-nodes/n8n-nodes-base.emailimap` | Trigger on new email |
| RSS Feed Trigger | `core-nodes/n8n-nodes-base.rssFeedReadTrigger` | New RSS item |
| Chat Trigger | `core-nodes/n8n-nodes-base.chatTrigger` | Used with AI Chat nodes |
| Local File Trigger | `core-nodes/n8n-nodes-base.localFileTrigger` | File system events |
| SSE Trigger | `core-nodes/n8n-nodes-base.sseTrigger` | Server-sent events |
| n8n Form Trigger | `core-nodes/n8n-nodes-base.formTrigger` | Web form submissions |
| Execute Sub-workflow Trigger | `core-nodes/n8n-nodes-base.executeWorkflowTrigger` | Called by another workflow |
| Error Trigger | `core-nodes/n8n-nodes-base.errorTrigger` | Catch workflow errors |

### Flow Control
| Node | Doc path | Notes |
|---|---|---|
| If | `core-nodes/n8n-nodes-base.if` | Boolean branch; use `typeValidation: "loose"` for mixed types |
| Switch | `core-nodes/n8n-nodes-base.switch` | Multi-branch routing |
| Loop Over Items | `core-nodes/n8n-nodes-base.splitInBatches` | Batch iterator; typeVersion 3: output 1 = items, output 0 = done |
| Wait | `core-nodes/n8n-nodes-base.wait` | Pause execution (time or webhook resume) |
| Stop And Error | `core-nodes/n8n-nodes-base.stopAndError` | Halt with custom error message |
| Execute Sub-workflow | `core-nodes/n8n-nodes-base.executeWorkflow` | Call another workflow |
| No Operation | `core-nodes/n8n-nodes-base.noOp` | Placeholder / passthrough |

### Data Manipulation
| Node | Doc path | Notes |
|---|---|---|
| Edit Fields (Set) | `core-nodes/n8n-nodes-base.set` | Add/overwrite/rename fields |
| Filter | `core-nodes/n8n-nodes-base.filter` | Remove items by condition |
| Sort | `core-nodes/n8n-nodes-base.sort` | Order items |
| Merge | `core-nodes/n8n-nodes-base.merge` | Combine two inputs |
| Split Out | `core-nodes/n8n-nodes-base.splitOut` | Flatten array field to items |
| Remove Duplicates | `core-nodes/n8n-nodes-base.removeDuplicates` | Dedup by field(s) |
| Rename Keys | `core-nodes/n8n-nodes-base.renameKeys` | Rename field keys |
| Aggregate | `core-nodes/n8n-nodes-base.aggregate` | Group items, collect to array |
| Compare Datasets | `core-nodes/n8n-nodes-base.compareDatasets` | Diff two item sets |
| Limit | `core-nodes/n8n-nodes-base.limit` | Cap item count |
| Summarize | `core-nodes/n8n-nodes-base.summarize` | Group + aggregate (count, sum, avg) |
| Data Table | `core-nodes/n8n-nodes-base.dataTable` | Tabular ops |

### HTTP / APIs
| Node | Doc path | Notes |
|---|---|---|
| HTTP Request | `core-nodes/n8n-nodes-base.httpRequest` | Generic REST/API calls |
| GraphQL | `core-nodes/n8n-nodes-base.graphql` | GraphQL queries |
| Respond to Webhook | `core-nodes/n8n-nodes-base.respondToWebhook` | Send HTTP response in webhook workflows |
| RSS Read | `core-nodes/n8n-nodes-base.rssFeedRead` | Fetch RSS feed once |

### Code / Scripting
| Node | Doc path | Notes |
|---|---|---|
| Code | `core-nodes/n8n-nodes-base.code` | JS or Python; runs in external runner |
| Execute Command | `core-nodes/n8n-nodes-base.executeCommand` | Shell command on host |
| LangChain Code | `cluster-nodes/root-nodes/n8n-nodes-langchain.code` | Custom LangChain JS |

### File / Format
| Node | Doc path | Notes |
|---|---|---|
| Read/Write Files | `core-nodes/n8n-nodes-base.readWriteFile` | Host filesystem |
| Extract From File | `core-nodes/n8n-nodes-base.extractFromFile` | CSV, JSON, XML, binary → items |
| Convert to File | `core-nodes/n8n-nodes-base.convertToFile` | Items → CSV, JSON, XLSX, etc. |
| Compression | `core-nodes/n8n-nodes-base.compression` | zip/gzip/tar |
| HTML | `core-nodes/n8n-nodes-base.html` | Parse / generate HTML |
| XML | `core-nodes/n8n-nodes-base.xml` | Parse / generate XML |
| Markdown | `core-nodes/n8n-nodes-base.markdown` | MD ↔ HTML conversion |
| Edit Image | `core-nodes/n8n-nodes-base.editImage` | Resize, crop, annotate images |

### Communication
| Node | Doc path | Notes |
|---|---|---|
| Send Email | `core-nodes/n8n-nodes-base.sendEmail` | SMTP |
| n8n Form | `core-nodes/n8n-nodes-base.form` | Render interactive form step |

### Auth / Security
| Node | Doc path | Notes |
|---|---|---|
| Crypto | `core-nodes/n8n-nodes-base.crypto` | Hash, HMAC, sign, encrypt |
| JWT | `core-nodes/n8n-nodes-base.jwt` | Sign and verify JWTs |
| TOTP | `core-nodes/n8n-nodes-base.totp` | Time-based OTP |

### Protocols
| Node | Doc path | Notes |
|---|---|---|
| FTP | `core-nodes/n8n-nodes-base.ftp` | FTP/SFTP file ops |
| SSH | `core-nodes/n8n-nodes-base.ssh` | Remote shell commands |
| Git | `core-nodes/n8n-nodes-base.git` | Git repo operations |
| LDAP | `core-nodes/n8n-nodes-base.ldap` | Directory queries |
| MQTT | (app node) | Pub/sub messaging |
| AMQP Sender | (app node) | RabbitMQ / AMQP |

### AI Utilities (core)
| Node | Doc path | Notes |
|---|---|---|
| AI Transform | `core-nodes/n8n-nodes-base.aiTransform` | Apply LLM to each item without building a chain |
| MCP Client | `core-nodes/n8n-nodes-base.mcpClient` | Call an MCP server endpoint |
| MCP Server Trigger | `core-nodes/n8n-nodes-base.mcpServerTrigger` | Expose workflow as MCP tool |

---

## AI / Cluster Nodes

Docs hub: https://docs.n8n.io/advanced-ai/  
Node list: https://docs.n8n.io/integrations/builtin/cluster-nodes/

Cluster nodes consist of a **root node** + one or more **sub-nodes** wired to its side inputs.

### Root Nodes

| Node | Purpose | Doc |
|---|---|---|
| **AI Agent** | Autonomous agent — selects tools, iterates until goal met | https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/ |
| **Basic LLM Chain** | Simple prompt → LLM → output; no tools | https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.chainllm/ |
| **Question and Answer Chain** | RAG: retrieve from vector store, answer with LLM | — |
| **Summarization Chain** | Map-reduce or stuff summarization of long docs | — |
| **Information Extractor** | Extract structured JSON from unstructured text | — |
| **Text Classifier** | Classify text into predefined categories | — |
| **Sentiment Analysis** | Detect positive / negative / neutral sentiment | — |
| **LangChain Code** | Drop-in custom LangChain JS chain | — |
| **Vector Store (insert)** | Upsert embeddings into a vector DB | — |
| **Vector Store (retrieve)** | Similarity search + optional Q&A | — |

#### AI Agent — Agent Types

| Type | When to use |
|---|---|
| **Tools Agent** (default) | Best all-around; enforces structured output; use with any LLM that supports tool-calling |
| **Conversational Agent** | Dialogue flows; keeps conversation history |
| **ReAct Agent** | Complex multi-step reasoning; Reason + Act loops |
| **Plan and Execute Agent** | Decomposes task into plan first, then executes steps |
| **OpenAI Functions Agent** | Uses OpenAI function-calling API specifically |
| **SQL Agent** | Generates and runs SQL against a DB; auto-discovers schema |

Docs: https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/tools-agent/

---

### Sub-Nodes — Language Models (Chat)

Attach to root node's **Language Model** input.

| Sub-node | Provider | Notes |
|---|---|---|
| `lmChatOpenAi` | OpenAI | GPT-4o, GPT-4.1, o3, etc. For LiteLLM: base URL = `http://host.docker.internal:24000/v1` |
| `lmChatAnthropic` | Anthropic | Claude 3.x / Claude 4.x |
| `lmChatGoogleGemini` | Google Gemini | |
| `lmChatMistralCloud` | Mistral AI | |
| `lmChatGroq` | Groq | Fast inference |
| `lmChatAwsBedrock` | AWS Bedrock | Claude, Llama, Titan |
| `lmChatAzureOpenAi` | Azure OpenAI | |
| `lmChatOllama` | Ollama | Local models (not in yai — no GPU) |
| `lmChatOpenRouter` | OpenRouter | Multi-provider routing |
| `lmChatDeepSeek` | DeepSeek | |
| `lmChatXAI` | xAI Grok | |
| `lmChatMiniMax` | MiniMax | |
| `lmChatMoonshot` | Moonshot Kimi | |
| `lmChatAlibabaTongyi` | Alibaba | |

---

### Sub-Nodes — Embeddings

Attach to root node's **Embeddings** input (vector store insert/retrieve).

| Sub-node | Provider |
|---|---|
| `embeddingsOpenAi` | OpenAI (`text-embedding-3-small` default) |
| `embeddingsGoogleGemini` | Google |
| `embeddingsCohere` | Cohere |
| `embeddingsAWSBedrock` | AWS Bedrock |
| `embeddingsAzureOpenAi` | Azure OpenAI |
| `embeddingsHuggingFace` | HuggingFace Inference |
| `embeddingsMistralCloud` | Mistral |
| `embeddingsOllama` | Ollama (local) |

---

### Sub-Nodes — Memory

Attach to root node's **Memory** input. Persists conversation context across agent turns.

| Sub-node | Backend | Notes |
|---|---|---|
| `memoryBufferWindow` | In-memory | Simple sliding window; lost on restart |
| `memoryChatManager` | Configurable | Chat Memory Manager — explicit get/set |
| `memoryPostgresChat` | Postgres | Persistent; use yai-postgres |
| `memoryRedisChat` | Redis | Fast; use yai-n8n-redis-1 |
| `memoryMongoDbChat` | MongoDB | |
| `memoryMotorhead` | Motorhead server | |
| `memoryXata` | Xata DB | |
| `memoryZep` | Zep | |

---

### Sub-Nodes — Tools

Attach to root node's **Tools** input. Agents call these to act on the world.

| Sub-node | What it does |
|---|---|
| `toolAiAgent` | Delegate to a child AI Agent (multi-agent orchestration) |
| `toolMcpClient` | Expose any MCP server's tools to the agent |
| `toolWorkflow` | Call another n8n workflow as a tool |
| `toolCode` | Arbitrary JS function the agent can invoke |
| `toolCalculator` | Math expressions |
| `toolWikipedia` | Wikipedia search |
| `toolSerpApi` | Google search via SerpApi key |
| `toolSearXNG` | Self-hosted SearXNG web search |
| `toolWolframAlpha` | Wolfram|Alpha computational knowledge |
| `toolVectorStoreSearch` | Semantic search against a vector store |
| `toolThink` | Internal reasoning step (Claude extended thinking style) |

---

### Sub-Nodes — Vector Stores

Used as both root nodes (insert/retrieve) and as retriever sub-nodes.

| Backend | Sub-node / Root node |
|---|---|
| **Qdrant** (yai default) | `vectorStoreQdrant` — host: `http://host.docker.internal:26000` |
| PGVector (Postgres) | `vectorStorePGVector` |
| Chroma | `vectorStoreChroma` |
| Pinecone | `vectorStorePinecone` |
| Weaviate | `vectorStoreWeaviate` |
| Redis | `vectorStoreRedis` |
| Supabase | `vectorStoreSupabase` |
| MongoDB Atlas | `vectorStoreMongoDBAtlas` |
| Milvus | `vectorStoreMilvus` |
| Azure AI Search | `vectorStoreAzureAiSearch` |
| Simple (in-memory) | `vectorStoreInMemory` |
| Zep | `vectorStoreZep` |

---

### Sub-Nodes — Document Loaders

Attach to vector store root node's **Document** input.

| Sub-node | Source |
|---|---|
| `documentDefaultDataLoader` | n8n binary data (file from previous node) |
| `documentGithubLoader` | GitHub repo files |

---

### Sub-Nodes — Text Splitters

Attach to document loaders. Control chunk size for embedding.

| Sub-node | Strategy |
|---|---|
| `textSplitterCharacter` | Split on a delimiter character |
| `textSplitterRecursiveCharacter` | Recursive by paragraph/sentence/word (recommended default) |
| `textSplitterTokens` | Split by token count |

---

### Sub-Nodes — Output Parsers

Attach to LLM chain / agent to enforce structured output.

| Sub-node | Output format |
|---|---|
| `outputParserStructured` | JSON Schema → typed object |
| `outputParserItemList` | Comma-separated list → array |
| `outputParserAutofixing` | Wraps another parser + retries on malformed output |

---

### Sub-Nodes — Retrievers

Used in Q&A chains for advanced retrieval strategies.

| Sub-node | Strategy |
|---|---|
| `retrieverVectorStore` | Standard similarity search |
| `retrieverContextualCompression` | Compress retrieved docs with LLM |
| `retrieverMultiQuery` | Generate multiple query variants, merge results |
| `retrieverWorkflow` | Custom retrieval via another n8n workflow |

---

### Sub-Nodes — Reranking

Reorder retrieved results by relevance.

| Sub-node | Notes |
|---|---|
| `rerankerCohere` | Cohere Rerank API |
| `rerankerModelSelector` | Pick best document with an LLM |

---

## App / Action Nodes (200+)

Full list: https://docs.n8n.io/integrations/builtin/app-nodes/

Each app node doc page covers:
- **Operations** (Create, Get, GetAll, Update, Delete, etc.)
- **Parameters** per operation
- **Credential** type required
- **Example** input/output

### Key nodes used in the yai stack

| Node | Package name | Notes |
|---|---|---|
| Postgres | `n8n-nodes-base.postgres` | Use yai internal DSN; avoid `$body$` dollar-quoting |
| Slack | `n8n-nodes-base.slack` | Use `messageType: "text"` not `"block"` |
| HTTP Request | `n8n-nodes-base.httpRequest` | Used for LiteLLM API, MinIO S3, Qdrant REST, etc. |
| OpenAI | `n8n-nodes-base.openAi` | Can point to LiteLLM base URL |
| Qdrant | (HTTP Request) | No native node; use HTTP Request against `http://host.docker.internal:26000` |

---

## Expression Quick Reference

```js
// Access current item
$json.fieldName
$json["field-with-dash"]

// Access item from another node
$('NodeName').item.json.field
$('NodeName').all()           // array of all items
$('NodeName').first().json    // first item

// Workflow / execution metadata
$workflow.id
$execution.id

// Date helpers
$now                          // current DateTime (Luxon object)
$today                        // today at midnight
$now.toISO()                  // ISO string
$now.minus({hours: 6}).toISO()

// Env / secrets (Code node only)
process.env.MY_VAR
```

---

## Useful Links

| Resource | URL |
|---|---|
| Node types overview | https://docs.n8n.io/integrations/builtin/node-types/ |
| Core nodes | https://docs.n8n.io/integrations/builtin/core-nodes/ |
| App nodes | https://docs.n8n.io/integrations/builtin/app-nodes/ |
| Cluster nodes (AI) | https://docs.n8n.io/integrations/builtin/cluster-nodes/ |
| Advanced AI hub | https://docs.n8n.io/advanced-ai/ |
| LangChain concepts | https://docs.n8n.io/advanced-ai/langchain/langchain-n8n/ |
| AI Agent node | https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/ |
| Tools Agent | https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/tools-agent/ |
| Basic LLM Chain | https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.chainllm/ |
| Community nodes | https://docs.n8n.io/integrations/community-nodes/installation/ |
| Expressions | https://docs.n8n.io/code/expressions/ |
| Workflow JSON schema | https://docs.n8n.io/workflows/export-import/ |
