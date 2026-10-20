---
trigger: always_on
---
Before making any changes to `Dockerfile`, `combine_config.json`, `nginx.conf`, or `docker-compose.yml`, read the instructions in `skills/mcp-aggregator-maintenance/SKILL.md`.

Core architectural rules:
1. Platform components (`supergateway`, `combine-mcp`) are strictly pinned to exact versions.
2. Direct patches to `dist` files or compiled binaries are forbidden.
3. Binary tools (e.g., `github-mcp-server`) are installed strictly as explicit version-pinned release assets, matching platform components.
