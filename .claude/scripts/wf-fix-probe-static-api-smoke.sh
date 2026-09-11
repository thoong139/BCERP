#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-api-smoke.sh — Static+Dynamic probe: Auth-aware API smoke test (QD1)
#
# IMP-006: Auth-aware api-smoke (EC-004 fix — 401/403 không còn bị flag là api_error).
# Detects API routes from source code (requires IMP-001 route probe output), then
# optionally makes HTTP calls against a running server. When 401 is received on first
# attempt, retries with credentials from auth config.
#
# Auth sources (priority order):
#   1. Env vars: MCV3_API_TOKEN, MCV3_API_KEY, MCV3_API_COOKIE
#   2. File: .mc-data/work/wf-fix-bugs/auth.json (or --auth-file <path>)
#
# Auth schemes:
#   bearer  — Authorization: Bearer <token>
#   cookie  — Cookie: session=<value>
#   apikey  — X-API-Key: <key>
#
# If no --base-url provided, or server unreachable: emits SPEC-ONLY-PROBE-SKIP.
# Routes sourced from IMP-001 output or --routes-file JSON.
#
# OUTPUT: JSON on stdout (schema lane-signals-v1)
#
# USAGE:
#   bash wf-fix-probe-static-api-smoke.sh \
#     --session-dir <path> --lane wf-fix-functional \
#     --probe P-QD1-api-smoke \
#     [--profile quick|standard|deep|exhaustive] \
#     [--base-url http://localhost:3000] \
#     [--auth-scheme bearer|cookie|apikey] \
#     [--auth-file .mc-data/work/wf-fix-bugs/auth.json] \
#     [--routes-file <path-to-route-signals.json>] \
#     [--source-dir src/] \
#     [--timeout-sec 10]
#
# EXIT CODES: 0 success, 1 error
#
# Author: IMP-006 Stage 3


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-functional"
PROBE_ID="P-QD1-api-smoke"
PROBE_VERSION="v1.0"
PROFILE="standard"
BASE_URL=""
AUTH_SCHEME="bearer"
AUTH_FILE_CLI=""
ROUTES_FILE=""
SOURCE_DIR="src/"
TIMEOUT_SEC=10

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir)    SESSION_DIR="$2";    shift 2 ;;
    --lane)           LANE="$2";           shift 2 ;;
    --probe)          PROBE_ID="$2";       shift 2 ;;
    --profile)        PROFILE="$2";        shift 2 ;;
    --base-url)       BASE_URL="$2";       shift 2 ;;
    --auth-scheme)    AUTH_SCHEME="$2";    shift 2 ;;
    --auth-file)      AUTH_FILE_CLI="$2";  shift 2 ;;
    --routes-file)    ROUTES_FILE="$2";    shift 2 ;;
    --source-dir)     SOURCE_DIR="$2";     shift 2 ;;
    --timeout-sec)    TIMEOUT_SEC="$2";    shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# Temp dir setup
# ============================================================
MCV3_TMP=""
if [ -n "$SESSION_DIR" ]; then
  MCV3_TMP="$SESSION_DIR/.probe-api-smoke-tmp"
  mkdir -p "$MCV3_TMP" 2>/dev/null || true
else
  MCV3_TMP="$(mktemp -d -t probe-api-smoke-XXXXXX)"
fi
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
: > "$SIGNALS_TMP"
trap 'rm -rf "$MCV3_TMP"' EXIT

# ============================================================
# Helper: emit signal to SIGNALS_TMP
# ============================================================
_emit_signal() {
  local severity="$1" fixability="$2" title="$3" description="$4" file="$5" line_val="$6"
  local fp
  fp=$(echo -n "QD1|$file|$line_val|$PROBE_ID|${title:0:30}" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg sev "$severity" --arg fix "$fixability" \
    --arg title "$title" --arg desc "$description" \
    --arg file "$file" --argjson line "$line_val" \
    --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2", dimension_id: "QD1",
      probe_id: $probe, probe_version: $pver,
      severity: $sev, fixability: $fix, domain: "api",
      title: $title, description: $desc,
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "stdout", path: $file, description: $desc}],
      cdg_flags: [], fingerprint: $fp,
      registry_refs: {}, detected_at: $now, detected_by: $detector
    }' >> "$SIGNALS_TMP"
}

# ============================================================
# Resolve auth credentials
# Priority: env vars > auth file
# ============================================================
AUTH_TOKEN="${MCV3_API_TOKEN:-}"
AUTH_KEY="${MCV3_API_KEY:-}"
AUTH_COOKIE="${MCV3_API_COOKIE:-}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
AUTH_FILE="${AUTH_FILE_CLI:-$REPO_ROOT/.mc-data/work/wf-fix-bugs/auth.json}"

if [ -z "$AUTH_TOKEN" ] && [ -z "$AUTH_KEY" ] && [ -z "$AUTH_COOKIE" ] && [ -f "$AUTH_FILE" ]; then
  AUTH_TOKEN=$(jq -r '.bearer_token // .token // empty' "$AUTH_FILE" 2>/dev/null || true)
  AUTH_KEY=$(jq -r '.api_key // empty' "$AUTH_FILE" 2>/dev/null || true)
  AUTH_COOKIE=$(jq -r '.session_cookie // empty' "$AUTH_FILE" 2>/dev/null || true)
fi

# Determine active credential for chosen scheme
case "$AUTH_SCHEME" in
  bearer)  CRED="$AUTH_TOKEN" ;;
  apikey)  CRED="$AUTH_KEY" ;;
  cookie)  CRED="$AUTH_COOKIE" ;;
  *)       CRED="" ;;
esac

# ============================================================
# Collect API route paths from routes-file or source scan
# ============================================================
ROUTES_TMP="$MCV3_TMP/routes.$$.txt"
: > "$ROUTES_TMP"

if [ -n "$ROUTES_FILE" ] && [ -f "$ROUTES_FILE" ]; then
  # Extract paths from IMP-001 route signal JSON
  jq -r '.signals[] | .location.url // (.title | ltrimstr("Route: ") | split(" ") | last)' \
    "$ROUTES_FILE" 2>/dev/null | grep '^/' | sort -u >> "$ROUTES_TMP" || true
fi

if [ ! -s "$ROUTES_TMP" ] && [ -d "$SOURCE_DIR" ]; then
  # Detect routes from source: Express/NestJS (.get('/path')), annotation-style (@GetMapping("/path"))
  # Two passes: double-quoted paths, then single-quoted paths
  grep -rEoh '\.(get|post|put|delete|patch|head)\([[:space:]]*"(/[^"]+)"' \
    "$SOURCE_DIR" 2>/dev/null \
    | grep -oE '(/[a-zA-Z0-9_/{}/:-]+)' | sort -u >> "$ROUTES_TMP" || true
  grep -rEoh "\\.(get|post|put|delete|patch|head)\\([[:space:]]*'(/[^']+)'" \
    "$SOURCE_DIR" 2>/dev/null \
    | grep -oE '(/[a-zA-Z0-9_/{}/:-]+)' | sort -u >> "$ROUTES_TMP" || true
  # Annotation-style (Spring, ASP.NET)
  grep -rEoh '@(Get|Post|Put|Delete|Patch|Request)Mapping\([[:space:]]*"(/[^"]+)"' \
    "$SOURCE_DIR" 2>/dev/null \
    | grep -oE '(/[a-zA-Z0-9_/{}/:-]+)' | sort -u >> "$ROUTES_TMP" || true
  grep -rEoh '\[(HttpGet|HttpPost|HttpPut|HttpDelete|HttpPatch)\([[:space:]]*"(/[^"]+)"' \
    "$SOURCE_DIR" 2>/dev/null \
    | grep -oE '(/[a-zA-Z0-9_/{}/:-]+)' | sort -u >> "$ROUTES_TMP" || true
fi

ROUTE_COUNT=$(wc -l < "$ROUTES_TMP" | tr -d ' ')

# ============================================================
# If no base URL, skip dynamic testing — emit SPEC-ONLY-PROBE-SKIP
# ============================================================
if [ -z "$BASE_URL" ]; then
  _emit_signal "info" "none" \
    "API smoke: SPEC-ONLY-PROBE-SKIP (no --base-url)" \
    "No --base-url provided. Dynamic API smoke test skipped. To enable: pass --base-url http://localhost:PORT. Auth config: $([ -n "$CRED" ] && echo "credentials loaded (scheme=$AUTH_SCHEME)" || echo "no credentials"). Routes detected: $ROUTE_COUNT." \
    "N/A" "0"
  # Emit info about detected routes as spec signals
  if [ "$ROUTE_COUNT" -gt 0 ]; then
    while IFS= read -r route; do
      [ -z "$route" ] && continue
      fp=$(echo -n "QD1|$route|0|$PROBE_ID|route_spec" | _sha256 | awk '{print "sha256:"$1}')
      jq -nc \
        --arg route "$route" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2", dimension_id: "QD1",
          probe_id: $probe, probe_version: $pver,
          severity: "info", fixability: "none", domain: "api",
          title: ("API route detected: " + $route),
          description: ("Route " + $route + " detected in source. Add --base-url to enable live smoke test."),
          location: {file: "N/A", line: null, column: null, selector: null, url: $route},
          evidence: [{type: "spec", path: "N/A", description: "Route found in source code"}],
          cdg_flags: [], fingerprint: $fp,
          registry_refs: {}, detected_at: $now, detected_by: $detector
        }' >> "$SIGNALS_TMP"
    done < "$ROUTES_TMP"
  fi

  jq -n \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    --slurpfile signals "$SIGNALS_TMP" \
    '{"$schema":"lane-signals-v1", lane:$lane, dimension:"QD1", probe_id:$probe,
      probe_version:$pver, profile:$profile, generated_at:$now, signals:$signals}'
  exit 0
fi

# ============================================================
# Dynamic smoke test: curl each route, handle 401 with auth retry
# ============================================================
# CRIT-6 fix v9.0.3: tra ve mang shell qua nameref (KHONG return string roi eval).
# Goi: _build_auth_curl_args <out_array_name> <scheme> <cred>
# Ket qua: array duoc assign 0 hoac 2 phan tu (-H, "<header line>"). Dam bao:
#   - Khong eval
#   - Credential khong di vao eval shell context
#   - Header value chua space/special chars van duoc curl quote dung
_build_auth_curl_args() {
  local -n _out="$1"
  local scheme="$2" cred="$3"
  _out=()
  [ -z "$cred" ] && return 0
  case "$scheme" in
    bearer) _out=(-H "Authorization: Bearer $cred") ;;
    apikey) _out=(-H "X-API-Key: $cred") ;;
    cookie) _out=(-H "Cookie: session=$cred") ;;
    *) _out=() ;;
  esac
}

if [ -s "$ROUTES_TMP" ]; then
  while IFS= read -r route; do
    [ -z "$route" ] && continue
    URL="${BASE_URL}${route}"

    # Attempt 1: no auth
    set +e
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time "$TIMEOUT_SEC" \
      --connect-timeout 5 \
      "$URL" 2>/dev/null || echo "000")
    set -e

    # If 401/403, attempt 2 with auth (IMP-006 core behavior)
    if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
      if [ -n "$CRED" ]; then
        # CRIT-6 fix: dung array thay vi eval — chong injection neu cred chua $/`/;/&&
        # `declare -a` thay vi `local -a` vi block nay nam o top-level (ngoai function).
        declare -a _AUTH_ARGS=()
        _build_auth_curl_args _AUTH_ARGS "$AUTH_SCHEME" "$CRED"
        set +e
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
          --max-time "$TIMEOUT_SEC" \
          --connect-timeout 5 \
          "${_AUTH_ARGS[@]}" \
          "$URL" 2>/dev/null || echo "000")
        set -e
        AUTH_USED="yes"
      else
        AUTH_USED="no_credentials"
      fi
    else
      AUTH_USED="not_needed"
    fi

    # Classify outcome
    if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" = "curl_error" ]; then
      _emit_signal "medium" "none" \
        "API route unreachable: $route" \
        "Route $route at $URL: connection failed (timeout or refused). Server may not be running. HTTP code: $HTTP_CODE." \
        "$URL" "0"
    elif echo "$HTTP_CODE" | grep -qE '^5'; then
      _emit_signal "high" "agent_fix" \
        "API route server error: $route (HTTP $HTTP_CODE)" \
        "Route $route returned HTTP $HTTP_CODE (server error). Auth used: $AUTH_USED. Investigate server logs." \
        "$URL" "0"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
      # Auth failed even after retry
      _emit_signal "medium" "config_change" \
        "API route auth failed: $route (HTTP $HTTP_CODE, scheme=$AUTH_SCHEME)" \
        "Route $route returned HTTP $HTTP_CODE after auth retry with scheme=$AUTH_SCHEME. Verify credentials in auth.json or env MCV3_API_TOKEN." \
        "$URL" "0"
    else
      # 2xx or 3xx: success
      _emit_signal "info" "none" \
        "API route OK: $route (HTTP $HTTP_CODE)" \
        "Route $route responded HTTP $HTTP_CODE. Auth used: $AUTH_USED." \
        "$URL" "0"
    fi
  done < "$ROUTES_TMP"
else
  _emit_signal "warn" "none" \
    "API smoke: no routes detected" \
    "No API routes found in source (source-dir=$SOURCE_DIR) or routes-file. Add IMP-001 route probe output via --routes-file." \
    "N/A" "0"
fi

jq -n \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{"$schema":"lane-signals-v1", lane:$lane, dimension:"QD1", probe_id:$probe,
    probe_version:$pver, profile:$profile, generated_at:$now, signals:$signals}'

exit 0
