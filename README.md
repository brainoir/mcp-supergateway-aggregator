# MCP Monolithic Aggregator

A unified, highly-optimized Docker infrastructure for running multiple Model Context Protocol (MCP) servers behind a single SSE (Server-Sent Events) endpoint. 

## Background and Upstream Credits

This project is a heavily modified and optimized infrastructure wrapper based on two core open-source technologies:
1. **[nazar256/combine-mcp](https://github.com/nazar256/combine-mcp):** The core aggregator binary written in Go that proxies multiple stdio-based MCP servers into a single interface, automatically prefixing tool names to avoid collisions.
2. **[supergateway](https://www.npmjs.com/package/supergateway):** A Node.js bridge by Supermachine that converts HTTP SSE requests into stdio calls.

### Why this repo exists?
While `combine-mcp` and `supergateway` are powerful tools, combining them with a dozen Node.js and Python-based MCP tools (Deep Research, Storybook/Figma, etc.) inside a Docker container introduces several architectural challenges, including memory leaks, zombie processes, routing issues, and timeouts. 

### Why use an Aggregator?
- **Multiplexing & Massive Memory Savings (1:N):** Standard `stdio` MCP spawns a new dedicated Node process for every open IDE window, causing catastrophic memory bloat (e.g., 3 open projects = 3 separate Node processes per tool). This SSE-based aggregator runs exactly ONE instance of each tool inside Docker and serves all IDE windows simultaneously over HTTP, saving gigabytes of RAM.
- **No Zombie Processes:** Direct binary execution and a custom `wrapper.js` to ensure proper `SIGTERM` signal propagation (replacing `npx` wrappers which leak memory).
- **No HTTP Timeouts (supergateway patch):** Includes a built-in patch for a critical `webStandardStreamableHttp.js` bug that otherwise crashes the Node process on long-running LLM requests.
- **OOM Protection:** Enforces strict V8 memory limits (`--max-old-space-size`) to keep memory footprint predictable under load.
- **NGINX Ingress:** A pre-configured NGINX proxy with `proxy_buffering off;` and extended 86400s timeouts for seamless SSE streaming to AI agents.

## Included MCP Servers
- `@modelcontextprotocol/server-filesystem`
- `tavily-mcp`
- `@upstash/context7-mcp`
- `@pinkpixel/deep-research-mcp`
- `@mui/mcp`
- `storybook-figma-mcp`
- `github-mcp-server`
- `repowise`

## Concurrency & R&D Directions

Because this aggregator multiplexes multiple clients (IDE windows) into a single set of Node.js processes, understanding the statefulness of each MCP tool is critical. 

**1. Stateless API Wrappers (100% Concurrency Safe)**
- *Tools:* `tavily-mcp`, `deep-research-mcp`, `github-mcp-server`, `context7-mcp`, `@mui/mcp`, `storybook-figma-mcp`
- *Behavior:* These tools execute asynchronous external API calls. Multiple agents can request deep research or GitHub operations simultaneously. The Node.js event loop handles them in parallel.
- *Bottleneck:* External API Rate Limits (HTTP 429).

**2. Local I/O Bound (Concurrency Safe)**
- *Tools:* `@modelcontextprotocol/server-filesystem`, `repowise`
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
