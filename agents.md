---
description: Developer guidelines for interacting with and modifying the MCP Monolithic Aggregator.
---

# Agent Guidelines: MCP Aggregator

When an AI Agent is modifying or managing this repository, the following rules MUST be followed to preserve the stability of the monolithic infrastructure. Keep in mind that this is a **universal wrapper**, and end-users will install their own arbitrary MCP servers inside it.

### 1. Process Management
**Rule:** Always use standard `npx -y <package>` or `uvx <package>` commands inside `combine_config.json` to launch MCP servers.
**Why:** The aggregator's Docker container natively handles POSIX signals, ensuring proper shutdown and preventing zombie processes without any additional wrappers.

### 2. Supergateway Patch
The base `supergateway` package has a critical bug: if a client disconnects before a response is ready, it throws an uncaught error `No connection established`, killing the entire container.
**Rule:** Ensure the `sed` patch in the Dockerfile is preserved:
`RUN find /usr -name "webStandardStreamableHttp.js" -exec sed -i 's/throw new Error/console.error/g' {} +`

### 3. NGINX Proxying
**Rule:** When adjusting `nginx.conf`, `proxy_buffering off;` must REMAIN disabled. Enabling buffering will break Server-Sent Events (SSE) streaming for AI agents, causing the IDE to time out waiting for JSON-RPC responses.

### 4. Memory Limits
Do NOT pass experimental or complex flags to `NODE_OPTIONS` (e.g. `--optimize-for-size`). This will crash the Node 20+ runtime. Limit it strictly to `--max-old-space-size`.

### 5. Config Pathing
`combine-mcp` requires absolute paths for its configuration environment variable. 
**Rule:** `MCP_CONFIG` must be explicitly set and point to the absolute path `/app/combine_config.json` inside the container.

### 6. Post-Installation & Skill Deployment
**Rule:** When you (the AI Agent) deploy or install this repository for a user, you should inform the user that two Agent Skills are provided out-of-the-box in the `.agents/skills/` directory:
- `mcp-aggregator-usage`: Instructions on connecting to the aggregator.
- `mcp-aggregator-maintenance`: Instructions on profiling memory and troubleshooting.
These skills will automatically become active when working inside this project. If the user wants to use them globally, they can manually copy them to their `~/.gemini/config/skills/` folder.
