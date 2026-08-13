# Cursor/Claude RAM usage cut 10x: I built an MCP aggregator that stops zombie Node processes eating your server

**TL;DR:** Standard MCP stdio spawns a full Node.js process per tool per IDE window. 8 tools x 3 projects = 24 Node processes eating 1.2-2.4 GB at idle. I built a Docker-based aggregator that runs 8 MCP tools in **248 MB idle** -- and kills every child process cleanly with POSIX `kill(-pgid)`.

---

## The Problem: Your RAM Is Being Eaten by Zombie Node Processes

If you use Cursor, Claude Desktop, or any IDE with MCP tools, you've probably configured something like:

```json
"mcpServers": {
  "tavily": { "command": "npx", "args": ["-y", "tavily-mcp"] },
  "context7": { "command": "npx", "args": ["-y", "@upstash/context7-mcp"] },
  "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem"] }
}
```

What actually happens:
1. Each tool spawns its own `npx` -> `node` process tree.
2. Each **IDE window** spawns another copy of every tool.
3. When you close a window, the processes **don't always die** -- especially with `npx` wrapper shims that detach children.

**Real data from my server (2026-07-08):**
- `n8n-mcp`: **4 concurrent instances** (14 MB -> 112 MB each) -- total **~400 MB wasted**
- `terminal-mcp-server`: **4 instances** (8 MB -> 58 MB each) -- **~200 MB wasted**
- `chrome-devtools-mcp`: **4 instances** (up to 144 MB each) -- **~576 MB wasted**

**3 tools, 12 orphaned processes, ~1.2 GB wasted.** And the user only needed 1 instance of each.

With 8+ MCP tools and 3 open projects, you're easily at **1.2-2.4 GB idle RAM** just from MCP tooling. This gets worse every time you restart your IDE.

## The Solution: Monolithic SSE Aggregator

I containerized everything into a single Docker stack:

- **combine-mcp** (Go): Proxies 8 stdio MCP servers into one unified interface, auto-prefixing tool names.
- **supergateway** (Node): Converts SSE/Streamable HTTP requests into stdio calls for combine-mcp.
- **NGINX**: Ingress with `proxy_buffering off` and 86,400-second timeouts for long LLM streams.
- **Custom SIGTERM fix**: Patched `supergateway`'s `stdioToStatelessStreamableHttp.js` with `process.kill(-pgid)` -- POSIX process group kill that cascades SIGTERM -> SIGKILL (2s grace) through every nested `npm exec`, `sh -c`, and `uvx` child process.

All your IDE windows point to **one URL**: `http://<host>:8100/mcp/aggregator/mcp`. One container, N clients.

## Real Benchmark Numbers

### Idle State
| Metric | Value |
|--------|-------|
| mcp-aggregator container | **248 MiB** |
| mcp-nginx container | 9 MiB |
| **Total stack** | **257 MiB** |
| Process count | 14 PID |
| Uptime | 3 days (stable) |

### Load Test: 5 Concurrent Tool Calls (2026-08-13)
| Phase | RAM | CPU% | PIDs |
|-------|-----|------|------|
| Idle | 248.8 MiB | 0% | 12 |
| Burst (t=2s) | 1.33 GiB | 498% | 260 |
| Peak (t=5s) | **2.77 GiB** | 519% | **601** |
| Post-load (+5s) | **248.7 MiB** | 0.01% | **12** |
| Orphan processes | **0** | -- | -- |

Per-tool latency: 11-14 s (includes npx/uvx cold-start + external API calls).

### Historical: 8-Tool Concurrent Burst (2026-07-08)
Peak **1.63 GB RSS** / 31 procs, clean recovery to 336 MB within 60s. **Zero zombies in all 52 monitoring snapshots.**

## stdio vs Aggregator (The Numbers That Matter)

| | stdio (8 tools, 3 windows) | Aggregator |
|---|---------------------------|------------|
| **Idle RAM** | ~1.2-2.4 GB | **248 MB** |
| **Peak RAM (5 concurrent)** | ~4-6 GB | **2.77 GB** |
| **Zombie processes** | Frequent | **Zero** (POSIX pgid-kill) |
| **Config per IDE** | 8 entries | **1 URL** |
| **Memory limit** | None | **5 GB hard cap** |

## Quickstart

```bash
git clone https://github.com/brainoir/mcp-supergateway-aggregator
cd mcp-supergateway-aggregator
cp .env.example .env   # fill in your API keys
docker compose up -d --build
```

Then in your IDE's `mcp_config.json`:

```json
{
  "mcpServers": {
    "mcp-aggregator": {
      "serverUrl": "http://<YOUR_SERVER_IP>:8100/mcp/aggregator/mcp"
    }
  }
}
```

## Included Tools (all 8)

`@modelcontextprotocol/server-filesystem` | `tavily-mcp` | `@upstash/context7-mcp` | `@pinkpixel/deep-research-mcp` | `@mui/mcp` | `storybook-figma-mcp` | `github-mcp-server` | `repowise` (Python)

## Technical Details

- **Container limit:** 5 GiB (Docker `deploy.resources.limits.memory`)
- **V8 heap cap:** `NODE_OPTIONS=--max-old-space-size=400`
- **Zombie prevention:** `apply_supergateway_fix.py` patches supergateway's compiled JS: child processes spawn with `detached: true`, and `res.on('close')` triggers `process.kill(-child.pid, 'SIGTERM')` -> 2s -> `SIGKILL`. This is a fixed version of the broken PR #151 approach (which read `/proc` and missed orphans reparented to tini/PID 1).
- **NGINX:** `proxy_buffering off` is critical -- without it, NGINX buffers the SSE stream and crashes on large responses.
- **Stateless:** The `streamableHttp` transport means each request is independent. Tradeoff: Playwright/Puppeteer were removed because stateless mode can't maintain browser sessions across tool calls.

## Known Limitations

- Peak 2.7 GiB under 5 concurrent calls (dominated by deep-research). Don't run 20 agents simultaneously.
- 11-14s cold-start per tool call (npx/uvx spawn). Subsequent calls within session are faster.
- Stateless -> no browser automation tools.
- Single point of failure (mitigated by `restart: unless-stopped`).

---

**Repo:** [github.com/brainoir/mcp-supergateway-aggregator](https://github.com/brainoir/mcp-supergateway-aggregator)

Would love feedback, especially around concurrent statefulness handling and whether anyone has solved the stateful-tool problem under streamable HTTP without losing the clean-process-kill guarantees.
