#!/usr/bin/env bash
# Daily retention wrapper — delete session videos older than RETENTION_DAYS (default 14).
# Installed to /opt/selenoid/bin/ via deploy.sh; cron: 0 3 * * *
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SELENOID_VIDEO_RETENTION_DAYS="${SELENOID_VIDEO_RETENTION_DAYS:-14}"
exec "${SCRIPT_DIR}/cleanup-videos.sh"
