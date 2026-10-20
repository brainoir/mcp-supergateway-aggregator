#!/bin/bash
LOG_DIR="${MCP_MEM_LOG_DIR:-./launch}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/mcp_memory_stats_$(date +%Y%m%d).log"
INTERVAL=30

echo "--- MCP Memory Logger Started at $(date -u +"%Y-%m-%dT%H:%M:%SZ") ---" >> "$LOG_FILE"
echo "Interval: ${INTERVAL}s | Target: mcp-aggregator + node/github processes" >> "$LOG_FILE"
echo "Format: [TIMESTAMP] PID STAT RSS(KB) VSZ(KB) COMMAND ARGS" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

while true; do
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Snapshot" >> "$LOG_FILE"
  ps -eo pid,stat,rss,vsz,comm,args | grep -iE 'mcp|combine|supergateway|tavily|context7|deep-research|github-mcp|filesystem' | grep -vE 'grep|mcp_mem_logger' >> "$LOG_FILE"
  echo "----------------------------------------" >> "$LOG_FILE"
  sleep $INTERVAL
done
