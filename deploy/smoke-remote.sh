#!/usr/bin/env bash
# Post-deploy smoke checks against a public Selenoid base URL.
set -euo pipefail

BASE_URL="${1:-${SELENOID_PUBLIC_URL:-}}"
if [[ -z "$BASE_URL" ]]; then
  echo "Usage: $0 <base-url>  (or set SELENOID_PUBLIC_URL)" >&2
  exit 1
fi
BASE_URL="${BASE_URL%/}"
SELENOID_USER="${SELENOID_USER:-user1}"
SELENOID_PASSWORD="${SELENOID_PASSWORD:-1234}"
AUTH=(-u "${SELENOID_USER}:${SELENOID_PASSWORD}")
CURL_RETRIES="${CURL_RETRIES:-5}"
CURL_RETRY_DELAY="${CURL_RETRY_DELAY:-3}"
PLAYWRIGHT_SMOKE_TIMEOUT="${PLAYWRIGHT_SMOKE_TIMEOUT:-20}"

curl_retry() {
  local url="$1" attempt
  shift
  for attempt in $(seq 1 "$CURL_RETRIES"); do
    if curl "$@" "$url"; then
      return 0
    fi
    if [[ "$attempt" -lt "$CURL_RETRIES" ]]; then
      echo "curl failed (attempt ${attempt}/${CURL_RETRIES}), retry in ${CURL_RETRY_DELAY}s..." >&2
      sleep "$CURL_RETRY_DELAY"
    fi
  done
  return 1
}

curl_http_code() {
  local url="$1" attempt code
  shift
  for attempt in $(seq 1 "$CURL_RETRIES"); do
    code="$(curl -s -o /dev/null -w "%{http_code}" "$@" "$url" 2>/dev/null || true)"
    if [[ -n "$code" && "$code" != "000" ]]; then
      echo "$code"
      return 0
    fi
    if [[ "$attempt" -lt "$CURL_RETRIES" ]]; then
      echo "no HTTP response (attempt ${attempt}/${CURL_RETRIES}), retry in ${CURL_RETRY_DELAY}s..." >&2
      sleep "$CURL_RETRY_DELAY"
    fi
  done
  echo "000"
  return 1
}

echo "=== GET $BASE_URL/status (no auth required) ==="
status_json="$(curl_retry "$BASE_URL/status" -fsSL)"
echo "$status_json" | (command -v jq >/dev/null && jq . || cat)

if ! command -v jq >/dev/null; then
  echo "jq not found — skipping browser version assertions" >&2
  exit 0
fi

echo "=== browser versions ==="
for pair in "chrome:148.0" "msedge:145.0" "playwright-chromium:1.61.1" "playwright-chrome:1.61.1" "playwright-msedge:1.61.1" "firefox:150.0"; do
  browser="${pair%%:*}"
  version="${pair##*:}"
  if jq -e --arg b "$browser" --arg v "$version" '.browsers[$b][$v] != null' <<<"$status_json" >/dev/null; then
    echo "OK  $browser $version"
  else
    echo "FAIL $browser $version not in /status" >&2
    exit 1
  fi
done

echo "=== GET $BASE_URL/ (UI, no auth) ==="
ui_code="$(curl_http_code "$BASE_URL/")"
if [[ "$ui_code" == "200" ]]; then
  echo "OK  UI is public (HTTP 200)"
else
  echo "FAIL UI should be public without credentials (HTTP $ui_code)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/wd/hub/status without auth (expect 401) ==="
wd_no_auth="$(curl_http_code "$BASE_URL/wd/hub/status")"
if [[ "$wd_no_auth" == "401" ]]; then
  echo "OK  /wd/hub requires auth (HTTP 401)"
else
  echo "FAIL /wd/hub should require auth (HTTP $wd_no_auth)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/wd/hub/status (with basic auth) ==="
wd_code="$(curl_http_code "$BASE_URL/wd/hub/status" "${AUTH[@]}")"
if [[ "$wd_code" == "200" ]]; then
  echo "OK  /wd/hub with auth (HTTP 200)"
else
  echo "FAIL /wd/hub with auth: HTTP $wd_code" >&2
  exit 1
fi

echo "=== GET $BASE_URL/playwright/... without auth (expect 400 — WS upgrade required) ==="
pw_code="$(curl_http_code "$BASE_URL/playwright/playwright-chromium/1.61.1" --max-time "$PLAYWRIGHT_SMOKE_TIMEOUT")"
if [[ "$pw_code" == "400" || "$pw_code" == "426" ]]; then
  echo "OK  /playwright/ is public for UI WebSocket (HTTP $pw_code)"
else
  echo "FAIL /playwright/ should be reachable without auth for UI (HTTP $pw_code, want 400)" >&2
  exit 1
fi

echo "Smoke OK: $BASE_URL (auth: $SELENOID_USER:***)"
