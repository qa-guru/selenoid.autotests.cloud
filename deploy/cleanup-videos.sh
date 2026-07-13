#!/usr/bin/env bash
# Remove Selenoid session videos older than retention window.
# - SELENOID_VIDEO_RETENTION_DAYS (e.g. 14) — daily cron via video-retention.sh
# - SELENOID_VIDEO_RETENTION_MONTHS (default 6) — monthly deep cleanup when DAYS unset
set -euo pipefail

VIDEO_DIR="${SELENOID_VIDEO_DIR:-/opt/selenoid/video}"
LOG_FILE="${SELENOID_VIDEO_CLEANUP_LOG:-/opt/selenoid/logs/video-cleanup.log}"
RETENTION_DAYS="${SELENOID_VIDEO_RETENTION_DAYS:-}"
RETENTION_MONTHS="${SELENOID_VIDEO_RETENTION_MONTHS:-6}"

mkdir -p "$(dirname "$LOG_FILE")"

if [[ ! -d "$VIDEO_DIR" ]]; then
  echo "$(date -Is) video dir missing: $VIDEO_DIR" >>"$LOG_FILE"
  exit 0
fi

BEFORE="$(find "$VIDEO_DIR" -type f 2>/dev/null | wc -l)"
DELETED=0

if [[ -n "$RETENTION_DAYS" ]]; then
  CUTOFF_LABEL="${RETENTION_DAYS}d"
  for _ in 1 2 3 4 5; do
    n="$(find "$VIDEO_DIR" -type f -mtime "+${RETENTION_DAYS}" -delete -print 2>/dev/null | wc -l)"
    DELETED=$((DELETED + n))
    [[ "$n" -eq 0 ]] && break
    sleep 1
  done
else
  CUTOFF_LABEL="${RETENTION_MONTHS}mo"
  CUTOFF="$(date -d "${RETENTION_MONTHS} months ago" +%Y-%m-%d)"
  for _ in 1 2 3 4 5; do
    n="$(find "$VIDEO_DIR" -maxdepth 1 -name '*.mp4' ! -newermt "$CUTOFF" -delete -print 2>/dev/null | wc -l)"
    DELETED=$((DELETED + n))
    [[ "$n" -eq 0 ]] && break
    sleep 1
  done
fi

AFTER="$(find "$VIDEO_DIR" -type f 2>/dev/null | wc -l)"
SIZE="$(du -sh "$VIDEO_DIR" 2>/dev/null | cut -f1)"

echo "$(date -Is) cutoff=$CUTOFF_LABEL deleted=$DELETED before=$BEFORE after=$AFTER size=$SIZE" >>"$LOG_FILE"
