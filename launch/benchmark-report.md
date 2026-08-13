# MCP Monolithic Aggregator — Benchmark Report

**Date:** 2026-08-13
**Repository:** [github.com/brainoir/mcp-supergateway-aggregator](https://github.com/brainoir/mcp-supergateway-aggregator)
**Host:** HP EliteDesk, Debian, 16 GB RAM, Docker

---

## 1. Architecture Overview

```
IDE Client 1 ─┐
IDE Client 2 ─┼── NGINX (:8100) ── supergateway (:8101, streamableHttp) ── combine-mcp (Go) ──┬── filesystem (npx)
IDE Client N ─┘    proxy_buffering    POSIX pgid-kill patch (SIGTERM -> SIGKILL)                ├── tavily (npx)
                   off, 86400s                                                                   ├── context7 (npx)
                   timeouts                                                                      ├── deep-research (npx)
                                                                                                 ├── mui (npx)
                                                                                                 ├── storybook-figma (npx)
                                                                                                 ├── github (npx)
                                                                                                 └── repowise (uvx)
```

- **combine-mcp** (Go): stdin-multiplexer that prefixes tool names to avoid collisions.
- **supergateway** (Node.js): Converts Streamable HTTP JSON-RPC into stdio calls for combine-mcp.
- **NGINX**: Ingress with `proxy_buffering off` (critical for SSE streaming) and 86400 s timeouts.
- **Container limit:** 5 GiB. **V8 cap:** `NODE_OPTIONS=--max-old-space-size=400`.
- **Zombie fix:** Custom POSIX `kill(-pgid)` patch via `apply_supergateway_fix.py` -- replaces the broken `/proc` parsing from PR #151 that missed orphans reparented to tini (PID 1).

## 2. Active MCP Servers (8 total)

| # | Server | Runtime | Transport |
|---|--------|---------|-----------|
| 1 | `@modelcontextprotocol/server-filesystem` | npx (Node) | stdio |
| 2 | `@mui/mcp` | npx (Node) | stdio |
| 3 | `storybook-figma-mcp` | npx (Node) | stdio |
| 4 | `tavily-mcp` | npx (Node) | stdio |
| 5 | `@upstash/context7-mcp` | npx (Node) | stdio |
| 6 | `@pinkpixel/deep-research-mcp` | npx (Node) | stdio |
| 7 | `repowise` | uvx (Python) | stdio |
| 8 | `github-mcp-server` | npx (Node) | stdio |

All tool names are prefixed by `combine-mcp` with their server key (e.g. `tavily_tavily_search`, `context7_context7_query_docs`).

## 3. Idle Metrics (Baseline)

Measured via `docker stats --no-stream` on 2026-08-13, container up for 3 days.

| Container | RAM | CPU | PIDs | Limit |
|-----------|-----|-----|------|-------|
| `mcp-aggregator` | **248.3 MiB** | 0.00% | 12 | 5 GiB |
| `mcp-nginx` | 9.2 MiB | 0.00% | 2 | -- |
| **Total stack** | **257.5 MiB** | -- | 14 | -- |

Host: 15,775 MB total / 4,348 MB used / 11,426 MB available.

## 4. Load Test -- 5 Concurrent Tool Calls (Fresh, 2026-08-13)

**Method:** 5 distinct tools called simultaneously via `curl` against `http://localhost:8100/mcp/aggregator/mcp`. `docker stats --no-stream` sampled at t=0s, t=2s, t=5s. Post-load measurement at +5s after completion.

### Latency

| Tool | Time | Status |
|------|------|--------|
| `github_git_status` | 11.29 s | 200 |
| `filesystem_list_directory` | 11.31 s | 200 |
| `repowise_list_repos` | 12.63 s | 200 |
| `tavily_tavily_search` | 13.55 s | 200 |
| `context7_resolve_library_id` | 13.65 s | 200 |
| **Average** | **12.49 s** | -- |

Latency includes cold-start of npx/uvx tool processes + external API calls.

### Memory and Processes Under Load

| Timestamp | RAM | CPU % | PIDs |
|-----------|-----|-------|------|
| t=0 (idle) | 248.8 MiB | 0.00% | 12 |
| t=2s (burst) | 1,325 MiB | 498% | 260 |
| t=5s (peak) | **2,770 MiB** | 519% | **601** |
| t=~16s (post-load) | **248.7 MiB** | 0.01% | **12** |

### Cleanup

After 5 requests completed + 5s grace: RAM back to 248.7 MiB, PIDs back to 12, 0 orphan processes.

## 5. Historical Stress Test (2026-07-08, 8 Concurrent Tools)

From `mcp_memory_stats.log` -- 52 snapshots at 5s intervals.

| Phase | Processes | RSS (host) |
|-------|-----------|------------|
| Idle | 8 | 336 MB |
| Ramp | 13 -> 31 | 486 -> 1,508 MB |
| **Peak (13:24:04Z)** | **31** | **1,627 MB** |
| Sustained (~40 s) | 31 | ~1,453 MB |
| **Recovery (13:25:19Z)** | **8** | **336 MB** |
| Post-recovery | 8 | 336 MB |

**Zombie count: 0 in all 52 snapshots.** Plateau corresponds to `deep-research` multi-step Tavily crawl.

## 6. Comparison: stdio vs Aggregator

### The stdio Problem

Standard stdio MCP spawns one process per tool per IDE window. 8 tools x 3 projects = 24 Node.js processes minimum. Idle RAM: ~1,200-2,400 MB.

Real host evidence (2026-07-08): `n8n-mcp` 4 instances (14-112 MB each), `terminal-mcp-server` 4 instances (8-58 MB), `chrome-devtools-mcp` 4 instances (up to 144 MB). **3 tools, 12 orphaned processes, ~1.2 GB wasted.**

### Aggregator Advantage

| Metric | stdio (8 tools, 3 windows) | Aggregator | Savings |
|--------|---------------------------|------------|---------|
| Idle RAM | ~1,200-2,400 MB (est.) | **248 MB** (measured) | ~5-10x |
| Peak RAM (5 concurrent) | ~4,000-6,000 MB (est.) | **2,770 MB** (measured) | ~2x |
| Docker mem limit | N/A | 5,120 MB (enforced) | -- |
| Idle process count | 24+ | 12 | ~2x |
| Orphan/zombie risk | High | **Zero** (POSIX pgid-kill) | -- |
| Config surface | 8 entries per IDE window | 1 URL | 8x less |
| API keys | Per-window env vars | Single `.env` | Centralized |

### Key Mechanisms

1. **1:N Multiplexing:** One container serves unlimited IDE windows. Adding a 4th project costs 0 MB.
2. **POSIX pgid-kill:** `kill(-pgid, SIGTERM)` -> 2s grace -> `kill(-pgid, SIGKILL)` cascades through all `npm exec`/`sh -c`/`uvx` children regardless of tini PID 1 reparenting.
3. **V8 cap:** `--max-old-space-size=400` prevents runaway Node.js heap.
4. **NGINX SSE tuning:** `proxy_buffering off` + 86,400s timeouts prevent long-stream crashes.
5. **Stateless transport:** `streamableHttp` means each request is a clean slate. Stateful tools (Playwright, Puppeteer) incompatible; removed.

## 7. Caveats

- Peak 2.7 GiB (5 concurrent) dominated by deep-research/tavily. 5 GiB limit fits ~8-10 concurrent calls.
- Latency 11-14s includes npx/uvx cold-start. Subsequent calls reuse warm stdio pipe.
- Stateless = no browser automation. Playwright/Puppeteer removed.
- Single point of failure: mitigated by `restart: unless-stopped`.
- Historical log: only ~4.5 min coverage from 2026-07-08 stress test.

## 8. Data Sources

- `mcp_memory_stats.log` (404 KB, 52 snapshots, 2026-07-08)
- `docker stats --no-stream` (2026-08-13 live)
- `free -m` (2026-08-13 host profile)
- Resolution reports: `resolution_supergateway_posix_fix.md`, `Final_Report_Playwright_Puppeteer_removed_2026-07-08.md`
