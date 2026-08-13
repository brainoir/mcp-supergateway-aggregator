# Plan: MCP Aggregator Benchmark (Stage 1) + Launch Content (Stage 2)

**Goal:** Produce a data-backed Benchmark Report for the MCP Monolithic Aggregator and four English-language launch posts (Reddit, Show HN, X/Twitter thread, Telegram) using only real measured numbers.

**Deliverable language:** English. Dialogue with user: Russian.

---

## 1. Context already collected (do NOT re-measure, reuse these numbers)

### Live idle metrics (measured 2026-08-13, `docker stats --no-stream`)
| Container | RAM | CPU | PIDs | Limit | Uptime |
|---|---|---|---|---|---|
| `mcp-aggregator` | 248.3 MiB | 0.00% | 12 | 5 GiB | 3 days |
| `mcp-nginx` | 9.2 MiB | 0.00% | 2 | — | 3 days |

Host: 15,775 MB total / 4,348 MB used / 11,426 MB available. Endpoint: `http://localhost:8100/mcp/aggregator/mcp` (NGINX → `mcp-aggregator:8101`).

### Historical stress test (from `/DATA/projects/my-server-proj/07_Issues/mcp-memory-profiling/mcp_memory_stats.log`, 2026-07-08, 52 snapshots @ 5s, 8-tool concurrent burst)
- Idle baseline: 8 procs, ~336 MB RSS (host-side `ps` view of aggregator tree).
- Burst at 13:23:18Z → **peak 1,627 MB RSS / 31 procs at 13:24:04Z**; sustained plateau ~1,450 MB for ~40 s (deep-research).
- Full recovery by 13:25:19Z: back to 8 procs / 336 MB. **Zero zombies in all 52 snapshots** (POSIX `kill(-pgid)` SIGTERM→2s grace→SIGKILL works).
- Note: logger is NOT running anymore (stopped 2026-07-08 13:27Z). Do not claim continuous monitoring.

### Evidence of the stdio duplication problem (from `reports/report_2026-07-08.md`)
- `n8n-mcp`: 4 concurrent instances, 14 → 112 MB each. `terminal-mcp-server`: 4 instances, 8 → 58 MB. `chrome-devtools-mcp`: 4 instances, up to 144 MB. Root cause: stdio MCP spawns one process tree per IDE window and old ones never die.

### Architecture facts (verified in repo)
- 8 MCP servers in `combine_config.json`: `filesystem`, `mui`, `storybook-figma`, `tavily`, `context7`, `deep-research`, `repowise` (Python/uvx), `github`.
- Stack: `combine-mcp` (Go binary) → `supergateway` (Node, port 8101, `streamableHttp`, stateless) → `tini` init → `NODE_OPTIONS=--max-old-space-size=400` → Docker mem limit 5120M → NGINX (`proxy_buffering off`, 86400 s timeouts).
- Zombie fix: `scripts/apply_supergateway_fix.py` patches `stdioToStatelessStreamableHttp.js` with detached spawn + `process.kill(-pgid)`. PR #151 was rejected (its `/proc` parsing misses orphans reparented to PID 1/tini).
- Repo: `github.com/brainoir/mcp-supergateway-aggregator`.

---

## 2. Stage 1 remaining work (implementation agent)

1. **Fresh live load test** to capture latency + confirm 2026-08-13 behavior:
   - Initialize session: `curl -sS -D - -o /dev/null http://localhost:8100/mcp/aggregator/mcp` (capture headers/transport).
   - Fire 3–5 concurrent JSON-RPC `tools/call` requests (e.g. `tavily_tavily_search`, `context7_resolve-library-id`, `filesystem_list_directory`, `github_*`) with `curl -w '%{time_total}'` in background jobs; record per-request latency.
   - During the burst sample `docker stats --no-stream` 2–3 times for peak RAM/CPU.
   - After disconnect: `ps -ef | grep -E 'node|mcp|uvx'` inside/near container to confirm zero orphans (expect cleanup within ~60 s, per historical log).
2. **Fix blocking repo bug before publishing:** `docker-compose.yml` references `Dockerfile.aggregator`, repo contains only `Dockerfile` → rename reference or file so a clean clone builds. (Minimal change.)
3. **Security (flag to user, do not silently fix):** GitHub PAT is stored plaintext in `.git/config` remote URL. Recommend token rotation + credential helper.
4. **Write Benchmark Report** (English) → `launch/benchmark-report.md` in the repo, containing: environment, method, the two tables above, fresh latency/load numbers, stdio-duplication evidence, and an honest comparison table (stdio N-process model vs 1:N aggregator). Include caveats: historical log covers only ~4.5 min; peak 1.6 GB under all-8-tools burst; stateless transport limitation.

## 3. Stage 2 deliverables (all English, saved under `launch/` in repo)

Accuracy constraints for ALL posts (violating these = hallucination):
- Say "SSE / Streamable HTTP", not plain "SSE" (transport is stateless `streamableHttp`).
- The SIGTERM mechanism is the **`apply_supergateway_fix.py` patch** (`kill(-pgid)`), NOT a `wrapper.js` (it does not exist). The README's wrapper.js mention is aspirational/outdated.
- Real numbers only: idle **248 MiB** (docker stats, 2026-08-13) or ~336 MB (host RSS, 2026-07-08); peak **~1.6 GB** under 8-tool burst; 0 zombies; 8 MCP servers; 5 GiB container limit; V8 cap 400 MB.
- Do not claim week-long monitoring; the logger ran ~4.5 minutes during the stress test.
- GitHub link: `https://github.com/brainoir/mcp-supergateway-aggregator`.

Files to create:
1. `launch/reddit-post.md` — Markdown, pain-point first (RAM bloat + zombie Node processes in Cursor/Claude), problem → solution (1:N multiplexing, pgid-kill patch, supergateway long-stream patch, NGINX buffering), benchmark table, quickstart (`docker-compose up -d --build` + client `mcp_config.json` snippet with `http://<host>:8100/mcp/aggregator/mcp`), repo link. Target subs: r/Cursor, r/ClaudeAI, r/LocalLLaMA, r/selfhosted.
2. `launch/show-hn.md` — plain text, zero hype. Title: `Show HN: MCP Monolithic Aggregator – Run N MCP servers in 1 Docker container over SSE (~250MB RAM)`. Explain stdio scaling failure, 1:N architecture (combine-mcp + supergateway + V8 limits + NGINX `proxy_buffering off`), exact numbers, and end asking for feedback on handling stateful tools under a stateless multiplexer (Playwright removal story).
3. `launch/x-thread.md` — 5 tweets (1/N…5/N): hook with metrics; stdio architectural flaw; Docker 1:N fix + patch + NGINX; tool list + memory limits; repo link + CTA.
4. `launch/telegram-post.md` — Telegram Markdown (bold headers, bullets, code blocks): personal tech-blog storytelling, same facts, tool list, repo + Docker setup link.

## 4. Validation

- Benchmark report numbers cross-checked against `mcp_memory_stats.log`, `docker stats` output and reports in `07_Issues/mcp-memory-profiling/reports/`.
- Every quantitative claim in each post must trace to a number in `launch/benchmark-report.md` (grep-check).
- `docker compose config` passes after the Dockerfile reference fix.
- Fresh load test: 0 zombie/orphan processes after disconnect; latency values recorded.

## 5. Out of scope / open items

- Restarting the long-term memory logger (recommend to user as follow-up, not required for posts).
- Token rotation (user action).
- Actually posting to Reddit/HN/X/Telegram (user publishes manually).
