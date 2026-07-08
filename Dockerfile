FROM node:20-bookworm-slim
WORKDIR /app

# Install system dependencies (tini, adb, python3 for HITL)
RUN apt-get update && apt-get install -y tini adb curl python3 python3-pip python3-venv && rm -rf /var/lib/apt/lists/*

# Install uv globally
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh

# Pre-install Python MCPs
RUN /usr/local/bin/uv tool install repowise

# Install all MCP tools globally via npm
RUN npm install -g \
    supergateway \
    @modelcontextprotocol/server-filesystem \
    tavily-mcp \
    @upstash/context7-mcp \
    @pinkpixel/deep-research-mcp \
    @mui/mcp \
    ajv-cli \
    storybook-figma-mcp \
    github-mcp-server

# Install combine-mcp binary
RUN curl -sSfL https://raw.githubusercontent.com/nazar256/combine-mcp/main/install.sh | bash

# Ensure the installed binary is in PATH
ENV PATH="/root/.local/bin:${PATH}"

# Setup combine-mcp config
COPY combine_config.json /app/combine_config.json

COPY scripts/apply_supergateway_fix.py /app/apply_supergateway_fix.py

# Apply PR #151 fix directly to compiled JS (avoids merge conflicts)
RUN python3 /app/apply_supergateway_fix.py

# Apply V8 memory tuning (only max-old-space-size is allowed in NODE_OPTIONS)
ENV NODE_OPTIONS="--max-old-space-size=400"

# Set combine-mcp config path
ENV MCP_CONFIG="/app/combine_config.json"

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["supergateway", "--port", "8101", "--outputTransport", "streamableHttp", "--stdio", "combine-mcp"]
