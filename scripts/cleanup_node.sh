#!/usr/bin/env bash
# ==============================================================================
# Node Cleanup & Decommissioning Script
# Executed during Destroy-Time Provisioners or Node Draining
# ==============================================================================
set -euo pipefail

NODE_ID="${1:-unknown}"

echo "======================================================================"
echo "[DECOMMISSION] Initiating graceful shutdown for node: ${NODE_ID}"
echo "======================================================================"

# 1. Gracefully stop application web services
if systemctl is-active --quiet nginx; then
    echo "[INFO] Stopping Nginx gracefully to finish in-flight requests..."
    systemctl stop nginx || true
fi

# 2. Flush pending system logs
sync
echo "[INFO] Synced disk caches."

# 3. Leave deregistration marker
echo "Node ${NODE_ID} successfully decommissioned at $(date -u +'%Y-%m-%dT%H:%M:%SZ')" > /tmp/decommissioned.log

echo "[SUCCESS] Cleanup routine completed."
exit 0
