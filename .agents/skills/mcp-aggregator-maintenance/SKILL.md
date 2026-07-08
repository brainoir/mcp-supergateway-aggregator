---
name: mcp-aggregator-maintenance
description: Instructions for profiling memory, identifying zombie processes, and maintaining the stability of the MCP Monolithic Aggregator.
---

# MCP Aggregator Maintenance & Profiling

This skill provides instructions for AI agents on how to maintain the health of the MCP Monolithic Aggregator, with a specific focus on memory leaks and V8 memory limits.

## Memory Profiling
Because this aggregator is a universal wrapper and can host any arbitrary MCP tools added by the user (including heavy ones like Chromium headless browsers, custom ML scripts, or AST parsers), memory profiling is periodically required.
There is an active memory logging system in place. Logs are gathered periodically and saved locally. 

**Log Location:** `07_Issues/mcp-memory-profiling/mcp_memory_stats.log`

### Analyzing Memory Logs
When tasked with investigating memory issues, you should read the `mcp_memory_stats.log`.
The logs are in the format: `PID STAT RSS(KB) VSZ(KB) COMMAND ARGS`

Look for:
1. **Uncontrolled RSS Growth:** Identify if specific tools installed by the user (e.g., custom scrapers, or memory-bound Python scripts) are steadily increasing their Resident Set Size (RSS) without dropping.
2. **Zombie Processes:** Look for `Z` in the `STAT` column. Zombie processes occur if a tool crashes and isn't cleaned up properly.
3. **Orphaned processes:** If you see dozens of orphaned processes, the aggregator is leaking processes on restarts. (Check for correct pathing or custom process handling).

### Applying Limits
If a Node.js-based MCP server is OOM-killing the container due to memory leaks, apply strict memory limits in `combine_config.json` via Node V8 flags, or globally in the Dockerfile:
`ENV NODE_OPTIONS="--max-old-space-size=400"`

*Note: Do not use experimental V8 flags (like `--optimize-for-size`), as they may crash Node 20+ runtimes.*
