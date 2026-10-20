---
name: mcp-aggregator-maintenance
description: Instructions for profiling memory, identifying zombie processes, maintaining the stability of the MCP Monolithic Aggregator, and developer guidelines for modification and installation.
---

# MCP Aggregator Maintenance & Profiling

This skill provides instructions for AI agents on how to maintain the health of the MCP Monolithic Aggregator, with a specific focus on memory leaks and V8 memory limits.

## Memory Profiling
Because this aggregator is a universal wrapper and can host any arbitrary MCP tools added by the user (including heavy ones like Chromium headless browsers, custom ML scripts, or AST parsers), memory profiling is periodically required.

Memory logging is performed by `scripts/mcp_mem_logger.sh`:
- **Interval:** 30 seconds.
- **Log Directory:** Specified via the `MCP_MEM_LOG_DIR` environment variable (defaults to `./launch/`).
- **Git Ignore:** All `*.log` files and the `launch/` directory are included in `.gitignore` and never committed.
- **Log Line Format:** `[TIMESTAMP] PID STAT RSS(KB) VSZ(KB) COMMAND ARGS`

### Analyzing Memory Logs
When tasked with investigating memory issues, read the memory log file provided by the user or located in `MCP_MEM_LOG_DIR` (or `./launch/mcp_memory_stats_YYYYMMDD.log`).
The logs follow the format: `PID STAT RSS(KB) VSZ(KB) COMMAND ARGS`

Look for:
1. **Uncontrolled RSS Growth:** Identify if specific tools installed by the user (e.g., custom scrapers, or memory-bound Python scripts) are steadily increasing their Resident Set Size (RSS) without dropping.
2. **Zombie Processes:** Look for `Z` in the `STAT` column. Zombie processes occur if a tool crashes and isn't cleaned up properly.
3. **Orphaned processes:** If you see dozens of orphaned processes, the aggregator is leaking processes on restarts. (Check for correct pathing or custom process handling).

### Applying Limits
If a Node.js-based MCP server is OOM-killing the container due to memory leaks, apply strict memory limits in `combine_config.json` via Node V8 flags, or globally in the Dockerfile:
`ENV NODE_OPTIONS="--max-old-space-size=400"`

*Note: Do not use experimental V8 flags (like `--optimize-for-size`), as they may crash Node 20+ runtimes.*


# Agent Guidelines: MCP Aggregator

When an AI Agent is modifying or managing this repository, the following rules MUST be followed to preserve the stability of the monolithic infrastructure. Keep in mind that this is a **universal wrapper**, and end-users will install their own arbitrary MCP servers inside it.

### 1. Process Management
**Rule:** Always use standard `npx -y <package>` or `uvx <package>` commands inside `combine_config.json` to launch MCP servers.
**Why:** The aggregator's Docker container natively handles POSIX signals (`SIGTERM`), ensuring proper process lifecycle management and clean shutdowns.

### 2. Platform Pinning & Process Lifecycle
Platform components are strictly version-pinned: `supergateway` (currently 4.2.0) and `combine-mcp` (currently v1.1.1). Binary tools (`github-mcp-server`) are also installed strictly as explicit version-pinned release assets (currently v2.0.2), matching platform components. Version 4 natively terminates child process groups upon connection close and on signal. Hosted npm-based tools (filesystem, tavily, context7, deep-research) are intentionally installed without version pins to automatically receive upstream updates.
**Rule:** Direct patches to `dist` are strictly forbidden; update platform and binary tools only via explicit pin bumps after reviewing upstream release notes.

### 3. NGINX Proxying
**Rule:** When adjusting `nginx.conf`, `proxy_buffering off;` must REMAIN disabled. Enabling buffering will break Server-Sent Events (SSE) streaming for AI agents, causing the IDE to time out waiting for JSON-RPC responses.

### 4. Memory Limits
Do NOT pass experimental or complex flags to `NODE_OPTIONS` (e.g. `--optimize-for-size`). This will crash the Node 20+ runtime. Limit it strictly to `--max-old-space-size`.

### 5. Config Pathing
`combine-mcp` requires absolute paths for its configuration environment variable. 
**Rule:** `MCP_CONFIG` must be explicitly set and point to the absolute path `/app/combine_config.json` inside the container.

