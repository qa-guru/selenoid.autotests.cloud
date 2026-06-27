#!/usr/bin/env bash
# Remove Selenoid session videos older than RETENTION_MONTHS.
# Installed on selenoid.autotests.cloud via root crontab (monthly).
set -euo pipefail

VIDEO_DIR="${SELENOID_VIDEO_DIR:-/opt/selenoid/video}"
LOG_FILE="${SELENOID_VIDEO_CLEANUP_LOG:-/opt/selenoid/logs/video-cleanup.log}"
RETENTION_MONTHS="${SELENOID_VIDEO_RETENTION_MONTHS:-6}"

if [[ ! -d "$VIDEO_DIR" ]]; then
  echo "$(date -Is) video dir missing: $VIDEO_DIR" >>"$LOG_FILE"
  exit 0
fi

CUTOFF="$(date -d "${RETENTION_MONTHS} months ago" +%Y-%m-%d)"
BEFORE="$(find "$VIDEO_DIR" -maxdepth 1 -name '*.mp4' 2>/dev/null | wc -l)"
DELETED=0
for _ in 1 2 3 4 5; do
  n="$(find "$VIDEO_DIR" -maxdepth 1 -name '*.mp4' ! -newermt "$CUTOFF" -delete -print 2>/dev/null | wc -l)"
  DELETED=$((DELETED + n))
  [[ "$n" -eq 0 ]] && break
  sleep 1
done
AFTER="$(find "$VIDEO_DIR" -maxdepth 1 -name '*.mp4' 2>/dev/null | wc -l)"
SIZE="$(du -sh "$VIDEO_DIR" 2>/dev/null | cut -f1)"

echo "$(date -Is) cutoff=$CUTOFF deleted=$DELETED before=$BEFORE after=$AFTER size=$SIZE" >>"$LOG_FILE"
