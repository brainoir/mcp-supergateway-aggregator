FROM node:20-bookworm-slim
WORKDIR /app

# Install system dependencies (tini, adb, python3 for HITL)
RUN apt-get update && apt-get install -y tini adb curl python3 python3-pip python3-venv && rm -rf /var/lib/apt/lists/*

# Install uv globally
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh

# Install all MCP tools globally via npm
RUN npm install -g \
    supergateway@4.2.0 \
    @modelcontextprotocol/server-filesystem \
    tavily-mcp \
    @upstash/context7-mcp \
    @pinkpixel/deep-research-mcp \
    ajv-cli

# Install official GitHub MCP server binary
RUN curl -sSfL https://github.com/github/github-mcp-server/releases/download/v2.0.2/github-mcp-server_Linux_x86_64.tar.gz | tar -xz -C /usr/local/bin github-mcp-server && \
    chmod +x /usr/local/bin/github-mcp-server

# Install combine-mcp binary
RUN mkdir -p /root/.local/bin && \
    curl -sSfL https://github.com/nazar256/combine-mcp/releases/download/v1.1.1/combine-mcp-linux-amd64.gz | gzip -dc > /root/.local/bin/combine-mcp && \
    chmod +x /root/.local/bin/combine-mcp

# Ensure the installed binary is in PATH
ENV PATH="/root/.local/bin:${PATH}"

# Setup combine-mcp config
COPY combine_config.json /app/combine_config.json

# Apply V8 memory tuning (only max-old-space-size is allowed in NODE_OPTIONS)
ENV NODE_OPTIONS="--max-old-space-size=400"

# Set combine-mcp config path
ENV MCP_CONFIG="/app/combine_config.json"

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["supergateway", "--port", "8101", "--outputTransport", "streamableHttp", "--stdio", "combine-mcp"]
