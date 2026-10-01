#!/usr/bin/env bash
# ==============================================================================
# Post-Provisioning Health Check & Verification Script
# ==============================================================================
set -euo pipefail

TARGET_HOST="${1:-}"
PORT="${2:-80}"
MAX_RETRIES=20
RETRY_INTERVAL=10

if [ -z "${TARGET_HOST}" ]; then
    echo "Usage: $0 <INSTANCE_IP_OR_HOSTNAME> [PORT]"
    exit 1
fi

echo "======================================================================"
echo "[HEALTH CHECK] Probing target: http://${TARGET_HOST}:${PORT}"
echo "======================================================================"

attempt=1
while [ ${attempt} -le ${MAX_RETRIES} ]; do
    echo "[Attempt ${attempt}/${MAX_RETRIES}] Testing HTTP endpoint..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${TARGET_HOST}:${PORT}" || echo "000")

    if [ "${HTTP_CODE}" == "200" ]; then
        echo "[SUCCESS] Received HTTP 200 OK from http://${TARGET_HOST}:${PORT}!"
        echo "[VERIFIED] Application server is healthy and accepting production traffic."
        exit 0
    else
        echo "[WAIT] Received HTTP ${HTTP_CODE}. Waiting ${RETRY_INTERVAL}s before next attempt..."
        sleep ${RETRY_INTERVAL}
    fi
    attempt=$((attempt + 1))
done

echo "[FAILURE] Application failed health check after ${MAX_RETRIES} attempts." >&2
exit 1
