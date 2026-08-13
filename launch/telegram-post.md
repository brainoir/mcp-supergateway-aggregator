**How I Cut MCP RAM Usage 10x with a Single Docker Container**

*If you use Cursor, Claude Desktop, or any IDE with MCP tools, your RAM is being silently eaten by zombie Node.js processes. I measured it, fixed it, and containerized the whole stack.*

---

**The Problem: Hidden Node.js Process Duplication**

When you add an MCP tool to your IDE config the standard way:

`"command": "npx", "args": ["-y", "tavily-mcp"]`

...each IDE window spawns its own copy. 8 tools × 3 Cursor windows = **24 Node.js processes** at idle.

Real data from my server (July 2026):
- `n8n-mcp`: *4 orphaned instances* (14–112 MB each)
- `chrome-devtools-mcp`: *4 instances* (up to 144 MB)
- `terminal-mcp-server`: *4 instances* (8–58 MB each)

**3 tools, 12 orphaned processes, ~1.2 GB wasted.**

---

**The Fix: Monolithic SSE Aggregator**

A Docker stack of three components:
- **combine-mcp** (Go): multiplexes 8 stdio MCP servers into one interface, auto-prefixing tool names
- **supergateway** (Node): converts SSE/Streamable HTTP JSON-RPC into stdio for combine-mcp
- **NGINX**: `proxy_buffering off` + 86400s timeouts for streaming

All IDE windows point to **one URL**: `http://<host>:8100/mcp/aggregator/mcp`

The critical hack: **POSIX `kill(-pgid)`** — process group kill on the kernel level. Unlike the PR #151 approach (which reads `/proc` and misses `tini`-reparented orphans), this cascades SIGTERM → 2s grace → SIGKILL through all `npm exec`, `sh -c`, and `uvx` children.

---

**Benchmarks (Real Numbers, August 2026)**

*Idle (containers up for 3 days):*

| Container | RAM | PIDs |
|-----------|-----|------|
| mcp-aggregator | **248 MiB** | 12 |
| mcp-nginx | 9 MiB | 2 |
| **Total** | **257 MiB** | 14 |

*Load test: 5 concurrent tool calls:*

| Phase | RAM | CPU% | PIDs |
|------|-----|------|------|
| Idle | 248.8 MiB | 0% | 12 |
| Peak (t=5s) | **2.77 GiB** | 519% | **601** |
| Post-load (+5s) | **248.7 MiB** | 0.01% | **12** |

Latency: 11–14s per call (including npx/uvx cold start + external APIs). Full cleanup in 5 seconds. **Zero zombie processes.**

---

**stdio vs Aggregator**

| Metric | stdio (8 tools, 3 windows) | Aggregator |
|--------|---------------------------|------------|
| Idle RAM | ~1.2–2.4 GB | **248 MB** |
| Peak RAM | ~4–6 GB | **2.77 GB** |
| Zombie risk | High | **Zero** |
| Config per IDE | 8 entries | **1 URL** |
| Memory limit | None | **5 GB (Docker)** |

---

**Included Tools (8):**

`filesystem` | `tavily-search` | `context7` | `deep-research` | `@mui/mcp` | `storybook-figma` | `github-mcp-server` | `repowise` (Python/uvx)

---

**Quickstart:**

```bash
git clone https://github.com/brainoir/mcp-supergateway-aggregator
cd mcp-supergateway-aggregator
cp .env.example .env   # API keys
docker compose up -d --build
```

IDE config:

```json
{"mcpServers": {"mcp-aggregator": {"serverUrl": "http://<YOUR_IP>:8100/mcp/aggregator/mcp"}}}
```

---

**Honest Limitations:**
- Peak 2.7 GB under 5 concurrent calls — don't run 20 agents simultaneously
- 11–14s latency includes npx/uvx cold-start costs
- Stateless transport → Playwright/Puppeteer removed (incompatible)
- Single point of failure (mitigated by `restart: unless-stopped`)

---

**Repo:** [github.com/brainoir/mcp-supergateway-aggregator](https://github.com/brainoir/mcp-supergateway-aggregator)

Full benchmark report, Dockerfile, and compose file in the repo. PRs welcome, especially around preserving stateful sessions under a stateless transport.
