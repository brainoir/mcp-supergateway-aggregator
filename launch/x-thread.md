Tweet 1/5

I cut my IDE's MCP RAM usage 10x with a single Docker container.

8 MCP tools: 248 MB idle, 2.7 GB peak under 5 concurrent calls, full cleanup in 5s, zero zombies.

Here's how the stdio MCP architecture fails and how I fixed it with POSIX process group kills + 1:N SSE multiplexing:

Tweet 2/5

The problem with stdio MCP:

Every IDE window spawns its own Node.js process per tool.

8 tools x 3 Cursor windows = 24 Node processes at idle, eating 1.2-2.4 GB RAM.

I found 12 orphaned MCP processes on my server:
- n8n-mcp: 4 copies (14-112 MB each)
- chrome-devtools-mcp: 4 copies (up to 144 MB)

Tweet 3/5

My fix: Monolithic MCP Aggregator in Docker.

Stack: NGINX -> supergateway (Node/SSE) -> combine-mcp (Go) -> [8 tools]

Key hack: Patched supergateway with process.kill(-pgid) -- POSIX process group kill.

SIGTERM -> 2s grace -> SIGKILL cascades through npm exec/sh -c/uvx children.

PR #151's /proc approach misses Docker orphans. pgid works on kernel level.

Tweet 4/5

Included tools:
filesystem | tavily-search | context7 | deep-research | MUI | storybook-figma | github | repowise (Python/uvx)

Memory limits:
- V8 heap: 400 MB max-old-space-size
- Docker: 5 GB hard cap
- NGINX: proxy_buffering off for SSE, 86400s timeouts

Verified: 0 zombie procs in 52 snapshots over stress test.

Tweet 5/5

Quickstart:
git clone github.com/brainoir/mcp-supergateway-aggregator
cp .env.example .env
docker compose up -d --build

1 URL in your IDE config:
http://<host>:8100/mcp/aggregator/mcp

~250 MB idle. Zero zombies. 8 tools.

Repo + benchmark report: github.com/brainoir/mcp-supergateway-aggregator

#MCP #Docker #DevTools #Cursor #ClaudeAI
