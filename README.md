# MCP Monolithic Aggregator

[![MCP Badge](https://lobehub.com/badge/mcp/brainoir-mcp-supergateway-aggregator)](https://lobehub.com/mcp/brainoir-mcp-supergateway-aggregator)

A unified, highly-optimized Docker infrastructure for running multiple Model Context Protocol (MCP) servers behind a single SSE (Server-Sent Events) endpoint. 

## Background and Upstream Credits

This project is a heavily modified and optimized infrastructure wrapper based on two core open-source technologies:
1. **[nazar256/combine-mcp](https://github.com/nazar256/combine-mcp):** The core aggregator binary written in Go that proxies multiple stdio-based MCP servers into a single interface, automatically prefixing tool names to avoid collisions.
2. **[supergateway](https://www.npmjs.com/package/supergateway):** A Node.js bridge by Supermachine that converts HTTP SSE requests into stdio calls.

### Why this repo exists?
While `combine-mcp` and `supergateway` are powerful tools, combining them with a dozen Node.js and Python-based MCP tools (Deep Research, Storybook/Figma, etc.) inside a Docker container introduces several architectural challenges, including memory leaks, zombie processes, routing issues, and timeouts. 

### Why use an Aggregator?
- **Multiplexing & Massive Memory Savings (1:N):** Standard `stdio` MCP spawns a new dedicated Node process for every open IDE window, causing catastrophic memory bloat (e.g., 3 open projects = 3 separate Node processes per tool). This SSE-based aggregator runs exactly ONE instance of each tool inside Docker and serves all IDE windows simultaneously over HTTP, saving gigabytes of RAM.
- **No Zombie Processes:** Native process-group reaping provided by supergateway 4.x (pinned to 4.2.0) and tini, ensuring proper termination of the entire process tree on disconnect or signals.
- **OOM Protection:** Enforces strict V8 memory limits (`--max-old-space-size`) to keep memory footprint predictable under load.
- **NGINX Ingress:** A pre-configured NGINX proxy with `proxy_buffering off;` and extended 86400s timeouts for seamless SSE streaming to AI agents.

## Included MCP Servers
- `@modelcontextprotocol/server-filesystem`
- `tavily-mcp`
- `@upstash/context7-mcp`
- `@pinkpixel/deep-research-mcp`
- `github-mcp-server` (official GitHub MCP server in Go, installed as a version-pinned release asset)

### Platform Pinning & Hosted Tools
The core platform components are strictly version-pinned to ensure stability and reliable process-tree cleanup: `supergateway` is pinned to `4.2.0` and `combine-mcp` to `v1.1.1`. In contrast, hosted MCP tools are intentionally installed without pinned versions to automatically receive upstream bug fixes, schema enhancements, and protocol updates on container rebuilds.

### Official GitHub MCP Server
Integrates the official Go-based `github-mcp-server` configured with 4 essential read-only search and inspection tools:
- `search_repositories` — search GitHub repositories
- `search_code` — search code across repositories
- `get_file_contents` — retrieve file contents
- `get_repository_tree` — inspect repository directory tree structures

Requires a GitHub Personal Access Token (`GITHUB_PERSONAL_ACCESS_TOKEN` in `.env`), preferably a fine-grained PAT with read-only permissions. If the token is omitted or invalid, the server will not start and the aggregator cleanly excludes it from the tool list without affecting the rest of the stack.

### Optional Tier-2 Servers
You can easily extend `combine_config.json` with additional or specialized servers:

```json
{
  "mcpServers": {
    "mui": {
      "command": "npx",
      "args": ["-y", "@mui/mcp"]
    },
    "storybook-figma": {
      "command": "npx",
      "args": ["-y", "storybook-figma-mcp"],
      "env": {
        "FIGMA_ACCESS_TOKEN": "figd_YOUR_TOKEN_HERE",
        "FIGMA_TEAM_ID": "YOUR_TEAM_ID"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://user:password@localhost:5432/dbname"]
    }
  }
}
```
*(For PostgreSQL, ensure `DATABASE_URI` is provided with a read-only database user for safety).*

## Concurrency & R&D Directions

Because this aggregator multiplexes multiple clients (IDE windows) into a single set of Node.js processes, understanding the statefulness of each MCP tool is critical. 

**1. Stateless API Wrappers (100% Concurrency Safe)**
- *Tools:* `tavily-mcp`, `deep-research-mcp`, `github-mcp-server`, `context7-mcp`
- *Behavior:* These tools execute asynchronous external API calls. Multiple agents can request deep research or GitHub operations simultaneously. The Node.js event loop handles them in parallel.
- *Bottleneck:* External API Rate Limits (HTTP 429).

**2. Local I/O Bound (Concurrency Safe)**
- *Tools:* `@modelcontextprotocol/server-filesystem`
- *Behavior:* Safe for concurrent reads/writes (mostly). 
- *Bottleneck:* Local RAM/CPU when parsing large repositories.

## Usage

1. Clone the repository.
2. Copy `.env.example` to `.env` and fill in your API keys (Tavily, Figma, GitHub, etc).
3. Review `combine_config.json` to enable or disable specific servers.
4. Start the stack:
   ```bash
   docker-compose up -d --build
   ```
5. Add the endpoint to your AI Agent's configuration (e.g., `mcp_config.json` or Cursor settings).

**Example Configuration:**
```json
"mcpServers": {
  "mcp-aggregator": {
    "serverUrl": "http://<YOUR_DOCKER_HOST_IP>:8100/mcp/aggregator/mcp"
  }
}
```
*(Note: Most modern clients like Antigravity or Cursor automatically infer the SSE transport from the HTTP `serverUrl`. For older clients, you may need to explicitly add `"transport": "sse"`).*

## License
MIT (Inherited from the base wrappers). 
