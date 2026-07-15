#!/usr/bin/env bash
# Post-deploy smoke checks against a public Selenoid base URL.
set -euo pipefail

BASE_URL="${1:-${SELENOID_PUBLIC_URL:-}}"
if [[ -z "$BASE_URL" ]]; then
  echo "Usage: $0 <base-url>  (or set SELENOID_PUBLIC_URL)" >&2
  exit 1
fi
BASE_URL="${BASE_URL%/}"
SELENOID_USER="${SELENOID_USER:-qa_engineer}"
SELENOID_PASSWORD="${SELENOID_PASSWORD:-aAb_-4gs53FD}"
AUTH=(-u "${SELENOID_USER}:${SELENOID_PASSWORD}")
PLAYWRIGHT_PUBLIC_KEY_DEFAULT='qa_engineer:aAb_-4gs53FD'
PLAYWRIGHT_STUDENT_ACCESS_KEY="${PLAYWRIGHT_STUDENT_ACCESS_KEY:-user1:1234}"
PLAYWRIGHT_PUBLIC_ACCESS_KEY="${PLAYWRIGHT_PUBLIC_ACCESS_KEY:-$PLAYWRIGHT_PUBLIC_KEY_DEFAULT}"
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

urlencode() {
  python -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
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
for pair in "chrome:149.0" "firefox:151.0" "msedge:145.0" "playwright-chromium:1.61.1" "playwright-chrome:1.61.1" "playwright-msedge:1.61.1"; do
  browser="${pair%%:*}"
  version="${pair##*:}"
  if jq -e --arg b "$browser" --arg v "$version" '.state.browsers[$b][$v] != null' <<<"$status_json" >/dev/null; then
    echo "OK  $browser $version"
  else
    echo "FAIL $browser $version not in /status" >&2
    exit 1
  fi
done

status_playwright_key="$(jq -r '.playwrightAccessKey // empty' <<<"$status_json")"
if [[ "$status_playwright_key" == "$PLAYWRIGHT_PUBLIC_ACCESS_KEY" ]]; then
  echo "OK  /status.playwrightAccessKey matches public guest SSOT"
elif [[ -z "$status_playwright_key" ]]; then
  # v2.3.0 UI binary has no -playwright-access-key; nginx map still gates /playwright/.
  echo "WARN /status.playwrightAccessKey empty (UI binary without flag) — nginx accessKey checks below"
else
  echo "FAIL /status.playwrightAccessKey: want ${PLAYWRIGHT_PUBLIC_ACCESS_KEY}, got: ${status_playwright_key}" >&2
  exit 1
fi

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
wd_json="$(curl_retry "$BASE_URL/wd/hub/status" -fsSL "${AUTH[@]}")"
echo "$wd_json" | (command -v jq >/dev/null && jq . || cat)
if ! jq -e '.value.ready == true' <<<"$wd_json" >/dev/null; then
  echo "FAIL /wd/hub/status ready!=true" >&2
  exit 1
fi
echo "OK  /wd/hub with auth (ready)"

# /status.version is selenoid-ui build stamp; hub revision lives in W3C /wd/hub/status.
EXPECTED_HUB_VERSION="${EXPECTED_HUB_VERSION:-${SELENOID_VERSION:-v2.3.0}}"
EXPECTED_HUB_VERSION="${EXPECTED_HUB_VERSION#v}"
hub_msg="$(jq -r '.value.message // empty' <<<"$wd_json")"
if [[ "$hub_msg" == *"Selenoid v${EXPECTED_HUB_VERSION}"* ]]; then
  echo "OK  hub version: $hub_msg"
else
  echo "FAIL hub version: want Selenoid v${EXPECTED_HUB_VERSION}*, got: ${hub_msg:-<empty>}" >&2
  exit 1
fi

ui_version="$(jq -r '.version // empty' <<<"$status_json")"
EXPECTED_UI_VERSION="${EXPECTED_UI_VERSION:-${SELENOID_UI_VERSION:-v2.3.0}}"
EXPECTED_UI_VERSION="${EXPECTED_UI_VERSION#v}"
# UI /status.version is gitRevision[buildStamp]. Accept exact tag, same minor
# (v2.3.0 pin vs latest-release stamp v2.3.2), or SELENOID_UI_GIT_REVISION.
EXPECTED_UI_MINOR="${EXPECTED_UI_VERSION%.*}"
UI_REV_OK=false
if [[ "$ui_version" == v${EXPECTED_UI_VERSION}* ]] || [[ "$ui_version" == ${EXPECTED_UI_VERSION}* ]]; then
  UI_REV_OK=true
elif [[ -n "$EXPECTED_UI_MINOR" && "$ui_version" == v${EXPECTED_UI_MINOR}.* ]]; then
  UI_REV_OK=true
fi
if [[ "$UI_REV_OK" != true ]]; then
  UI_ALT="${SELENOID_UI_GIT_REVISION:-${GIT_REVISION:-}}"
  UI_ALT="${UI_ALT#v}"
  if [[ -n "$UI_ALT" && "$ui_version" == ${UI_ALT}* ]]; then
    UI_REV_OK=true
  fi
fi
if [[ "$UI_REV_OK" == true ]]; then
  echo "OK  UI /status.version: $ui_version"
else
  echo "FAIL UI version: want v${EXPECTED_UI_VERSION}* / v${EXPECTED_UI_MINOR}.* (or SELENOID_UI_GIT_REVISION), got: ${ui_version:-<empty>}" >&2
  exit 1
fi

echo "=== GET $BASE_URL/playwright/... without accessKey (expect 401) ==="
pw_no_key="$(curl_http_code "$BASE_URL/playwright/playwright-chromium/1.61.1" --max-time "$PLAYWRIGHT_SMOKE_TIMEOUT")"
if [[ "$pw_no_key" == "401" ]]; then
  echo "OK  /playwright/ requires accessKey at nginx edge (HTTP 401)"
else
  echo "FAIL /playwright/ should require accessKey (HTTP $pw_no_key, want 401)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/playwright/... with student/public accessKey (expect 400 — WS upgrade required) ==="
for key in "$PLAYWRIGHT_STUDENT_ACCESS_KEY" "$PLAYWRIGHT_PUBLIC_ACCESS_KEY"; do
  encoded_key="$(urlencode "$key")"
  pw_code="$(curl_http_code "$BASE_URL/playwright/playwright-chromium/1.61.1?accessKey=${encoded_key}" --max-time "$PLAYWRIGHT_SMOKE_TIMEOUT")"
  if [[ "$pw_code" == "400" || "$pw_code" == "426" ]]; then
    echo "OK  /playwright/ accepts accessKey=${key%%:*}:*** (HTTP $pw_code)"
  else
    echo "FAIL /playwright/ should accept accessKey=${key%%:*}:*** (HTTP $pw_code, want 400/426)" >&2
    exit 1
  fi
done

echo "=== GET $BASE_URL/logs/unknown-session with auth (expect 400 — WS upgrade required) ==="
logs_code="$(curl_http_code "$BASE_URL/logs/unknown-session" "${AUTH[@]}")"
if [[ "$logs_code" == "400" ]]; then
  echo "OK  /logs/ proxied to hub (HTTP 400)"
else
  echo "FAIL /logs/ should proxy to hub with auth (HTTP $logs_code, want 400)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/logs/unknown-session without auth (expect 401) ==="
logs_no_auth="$(curl_http_code "$BASE_URL/logs/unknown-session")"
if [[ "$logs_no_auth" == "401" ]]; then
  echo "OK  /logs/ requires auth (HTTP 401)"
else
  echo "FAIL /logs/ should require auth (HTTP $logs_no_auth)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/error with auth (expect 404 — invalid session JSON) ==="
# Hub returns HTTP 404 with valid JSON — do not use curl -f here.
error_json="$(curl -sSL "${AUTH[@]}" "$BASE_URL/error" 2>/dev/null || true)"
echo "$error_json" | (command -v jq >/dev/null && jq . || cat)
if jq -e '.value.error == "invalid session id"' <<<"$error_json" >/dev/null; then
  echo "OK  /error proxied to hub (invalid session JSON)"
else
  echo "FAIL /error should proxy to hub invalid-session JSON" >&2
  exit 1
fi

echo "=== GET $BASE_URL/error without auth (expect 401) ==="
error_no_auth="$(curl_http_code "$BASE_URL/error")"
if [[ "$error_no_auth" == "401" ]]; then
  echo "OK  /error requires auth (HTTP 401)"
else
  echo "FAIL /error should require auth (HTTP $error_no_auth)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/vnc/unknown-session with auth (expect 400 — WS upgrade required) ==="
vnc_code="$(curl_http_code "$BASE_URL/vnc/unknown-session" "${AUTH[@]}")"
if [[ "$vnc_code" == "400" ]]; then
  echo "OK  /vnc/ proxied to hub (HTTP 400)"
else
  echo "FAIL /vnc/ should proxy to hub with auth (HTTP $vnc_code, want 400)" >&2
  exit 1
fi

echo "=== GET $BASE_URL/vnc/unknown-session without auth (expect 401) ==="
vnc_no_auth="$(curl_http_code "$BASE_URL/vnc/unknown-session")"
if [[ "$vnc_no_auth" == "401" ]]; then
  echo "OK  /vnc/ requires auth (HTTP 401)"
else
  echo "FAIL /vnc/ should require auth (HTTP $vnc_no_auth)" >&2
  exit 1
fi

echo "Smoke OK: $BASE_URL (auth: $SELENOID_USER:***)"
