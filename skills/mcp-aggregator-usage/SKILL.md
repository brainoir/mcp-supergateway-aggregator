---
name: mcp-aggregator-usage
description: Instructions for AI agents on how to connect to and utilize the deployed Monolithic MCP Aggregator via SSE (Server-Sent Events).
---

# MCP Aggregator Usage

This skill provides context on how to interact with the Monolithic MCP Aggregator once it is deployed (e.g., on a Linux server, Windows host, or Raspberry Pi).

## Endpoint Structure
The aggregator exposes multiple MCP tools behind a single NGINX reverse proxy using Server-Sent Events (SSE).
By default, the endpoint is accessible at:
`http://<HOST_IP>:8100/mcp/aggregator/`

## Tools Included
The aggregator automatically prefixes tool names to avoid collisions. The exact tools available depend on how the user configures `combine_config.json`.
By default, the provided example stack includes:
- `filesystem_*` (File operations within allowed paths)
- `tavily_*` (Web search and scraping)
- `github_*` (GitHub operations)
- *Users can install and configure any arbitrary Node.js, Python, or Go MCP server.*

## Configuration for Agents
To connect an IDE or another agent to this aggregator, configure the MCP client to use the SSE HTTP transport instead of standard `stdio`.

Example `mcp_config.json` entry:
```json
"mcpServers": {
  "mcp-aggregator": {
    "serverUrl": "http://<HOST_IP>:8100/mcp/aggregator/mcp"
  }
}
```
*(Note: Using an HTTP URL usually implies SSE automatically in clients like Antigravity. The exact configuration format depends on your IDE).*

## Important Constraints
- **Timeouts:** The NGINX proxy has an 86400s timeout to support long-running tasks. Do not arbitrarily terminate connections if a task is taking time.
- **Allowed Paths:** The `filesystem` tools are strictly constrained to paths defined in `ALLOWED_WRITE_PATHS` (via `.env` or `docker-compose.yml` during deployment).
