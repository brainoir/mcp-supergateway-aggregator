Show HN: MCP Monolithic Aggregator -- Run N MCP servers in 1 Docker container over SSE (~250MB RAM)

https://github.com/brainoir/mcp-supergateway-aggregator

The stdio-based MCP architecture has a scaling problem: every IDE window spawns its own copy of every configured MCP server. 8 tools across 3 windows = 24 Node.js processes, eating 1.2-2.4 GB idle RAM. I found 12 orphaned MCP processes on my server just from normal use -- n8n-mcp had 4 concurrent instances (14-112 MB each), chrome-devtools-mcp 4 instances (up to 144 MB each).

I built a Docker-based aggregator that runs 8 MCP servers behind a single SSE/Streamable HTTP endpoint:

Architecture: NGINX (proxy_buffering off, 86400s timeouts) -> supergateway (Node, streamableHttp transport, port 8101) -> combine-mcp (Go, stdin multiplexer) -> [filesystem, tavily, context7, deep-research, mui, storybook-figma, github, repowise]

Key technical decisions:

1. POSIX process group kill instead of /proc scanning. The PR #151 patch for supergateway reads /proc to find child PIDs, but misses orphans reparented to tini (PID 1) in Docker. My fix uses kill(-pgid, SIGTERM) with a 2-second grace period before SIGKILL -- this cascades through npm exec, sh -c, and uvx wrapper processes regardless of current parent PID.

2. V8 memory cap. NODE_OPTIONS=--max-old-space-size=400 constrains the supergateway Node process. Docker limits the container to 5 GiB total.

3. NGINX proxy_buffering off. Without this, NGINX holds the SSE stream in buffers and crashes on large LLM tool responses. Timeouts bumped to 86400s (24h).

4. Stateless streamableHttp transport. Each JSON-RPC request is independent -- no session state. This means Playwright/Puppeteer (which need browser sessions across calls) were removed, but it guarantees clean process lifecycle: every child process group terminates deterministically after its request completes.

Benchmark results (HP EliteDesk, 16 GB RAM, Debian, Docker):

Idle: 248 MiB (container), 9 MiB (nginx) = 257 MiB total stack
5 concurrent tool calls: peak 2,770 MiB / 601 PIDs, full recovery to 248.7 MiB / 12 PIDs in 5 seconds
8 concurrent tool calls (historical, 2026-07-08): peak 1,627 MB RSS / 31 PIDs, recovery to 336 MB
Zero zombie processes across all test runs
Per-request latency: 11-14 seconds (includes npx/uvx cold start + external API calls)

Comparison to stdio approach:
- Idle RAM: ~1,200-2,400 MB (stdio) vs 248 MB (aggregator) -- 5-10x savings
- Peak RAM under 5 concurrent: ~4,000-6,000 MB (stdio est.) vs 2,770 MB (aggregator) -- 2x savings
- Zombie risk: high (no lifecycle management in stdio) vs zero (POSIX pgid-kill guarantee)
- Configuration: 8 entries per IDE window vs 1 URL

Quickstart:
  git clone https://github.com/brainoir/mcp-supergateway-aggregator
  cp .env.example .env   # API keys
  docker compose up -d --build

Client config (mcp_config.json):
  {"mcpServers": {"mcp-aggregator": {"serverUrl": "http://<host>:8100/mcp/aggregator/mcp"}}}

I'm interested in community feedback on handling statefulness under the stateless multiplexer constraint. My current approach is to simply exclude stateful tools (Playwright, Puppeteer), but I've been thinking about request-scoped state management using Docker container labels or a sidecar session tracker. Would using the SSE transport's inherent session model (vs streamableHttp) be worth the added complexity of per-session cleanup?
