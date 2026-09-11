#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-infra-preflight.sh — Probe: Infrastructure Preflight check (QD1)
#
# IMP-007: Retry logic 3×5s cho infra-preflight — tránh false CRITICAL khi cold start.
# Evidence: Stage 1 QD1 FP-005 (cold start timeout → premature CRITICAL signal).
#
# Checks infrastructure readiness (server health, DB connection, external deps).
# Retries --infra-retry-count times with --infra-retry-interval second pauses.
# Default values loaded from _shared/profiles.json (IMP-004 dependency).
#
# If no --health-url: emits SPEC-ONLY-PROBE-SKIP (no running server).
#
# USAGE:
#   bash wf-fix-probe-static-infra-preflight.sh \
#     --session-dir <path> --lane wf-fix-functional \
#     --probe P-QD1-infra-preflight \
#     [--profile quick|standard|deep|exhaustive] \
#     [--health-url http://localhost:3000/health] \
#     [--infra-retry-count 3] \
#     [--infra-retry-interval 5] \
#     [--threshold-overrides '{"infra_retry_count":5}'] \
#     [--timeout-sec 10]
#
# EXIT CODES: 0 success, 1 error
#
# Author: IMP-007 Stage 3


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-functional"
PROBE_ID="P-QD1-infra-preflight"
PROBE_VERSION="v1.0"
PROFILE="standard"
HEALTH_URL=""
INFRA_RETRY_COUNT_CLI=-1
INFRA_RETRY_INTERVAL_CLI=-1
THRESHOLD_OVERRIDES="{}"
TIMEOUT_SEC=10

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir)          SESSION_DIR="$2";           shift 2 ;;
    --lane)                 LANE="$2";                  shift 2 ;;
    --probe)                PROBE_ID="$2";              shift 2 ;;
    --profile)              PROFILE="$2";               shift 2 ;;
    --health-url)           HEALTH_URL="$2";            shift 2 ;;
    --infra-retry-count)    INFRA_RETRY_COUNT_CLI="$2"; shift 2 ;;
    --infra-retry-interval) INFRA_RETRY_INTERVAL_CLI="$2"; shift 2 ;;
    --threshold-overrides)  THRESHOLD_OVERRIDES="$2";   shift 2 ;;
    --timeout-sec)          TIMEOUT_SEC="$2";           shift 2 ;;
    --source-dir)           SOURCE_DIR="$2";            shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# IMP-004: Load retry defaults from profiles.json
# ============================================================
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
PROFILES_JSON="$REPO_ROOT/.claude/skills/workflow/_shared/profiles/profiles.json"

_infra_profile_threshold() {
  local key="$1" default="$2"
  if [ -f "$PROFILES_JSON" ]; then
    local val
    val=$(jq -r --arg p "$PROFILE" --arg k "$key" \
      '.profiles[$p].thresholds[$k] // empty' "$PROFILES_JSON" 2>/dev/null || true)
    [ -n "$val" ] && [ "$val" != "null" ] && echo "$val" && return
  fi
  echo "$default"
}

# Load profile defaults
INFRA_RETRY_COUNT=$(_infra_profile_threshold "infra_retry_count" 3)
INFRA_RETRY_INTERVAL=$(_infra_profile_threshold "infra_retry_interval_sec" 5)

# Apply --threshold-overrides
_ov_count=$(jq -r '.infra_retry_count // empty' <<< "$THRESHOLD_OVERRIDES" 2>/dev/null || true)
[ -n "$_ov_count" ] && [ "$_ov_count" != "null" ] && INFRA_RETRY_COUNT="$_ov_count"
_ov_interval=$(jq -r '.infra_retry_interval_sec // empty' <<< "$THRESHOLD_OVERRIDES" 2>/dev/null || true)
[ -n "$_ov_interval" ] && [ "$_ov_interval" != "null" ] && INFRA_RETRY_INTERVAL="$_ov_interval"

# Explicit CLI wins over everything
[ "$INFRA_RETRY_COUNT_CLI" -ge 0 ] 2>/dev/null && INFRA_RETRY_COUNT="$INFRA_RETRY_COUNT_CLI"
[ "$INFRA_RETRY_INTERVAL_CLI" -ge 0 ] 2>/dev/null && INFRA_RETRY_INTERVAL="$INFRA_RETRY_INTERVAL_CLI"

# ============================================================
# Temp dir setup
# ============================================================
MCV3_TMP=""
if [ -n "$SESSION_DIR" ]; then
  MCV3_TMP="$SESSION_DIR/.probe-infra-tmp"
  mkdir -p "$MCV3_TMP" 2>/dev/null || true
else
  MCV3_TMP="$(mktemp -d -t probe-infra-XXXXXX)"
fi
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
: > "$SIGNALS_TMP"
trap 'rm -rf "$MCV3_TMP"' EXIT

# ============================================================
# Helper: emit signal
# ============================================================
_emit_signal() {
  local severity="$1" fixability="$2" title="$3" description="$4"
  local fp
  fp=$(echo -n "QD1|infra|0|$PROBE_ID|${title:0:40}" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg sev "$severity" --arg fix "$fixability" \
    --arg title "$title" --arg desc "$description" \
    --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2", dimension_id: "QD1",
      probe_id: $probe, probe_version: $pver,
      severity: $sev, fixability: $fix, domain: "infra",
      title: $title, description: $desc,
      location: {file: "N/A", line: null, column: null, selector: null, url: null},
      evidence: [{type: "stdout", path: "N/A", description: $desc}],
      cdg_flags: [], fingerprint: $fp,
      registry_refs: {}, detected_at: $now, detected_by: $detector
    }' >> "$SIGNALS_TMP"
}

# ============================================================
# No health-url → SPEC-ONLY-PROBE-SKIP
# ============================================================
if [ -z "$HEALTH_URL" ]; then
  _emit_signal "info" "none" \
    "Infra preflight: SPEC-ONLY-PROBE-SKIP (no --health-url)" \
    "No --health-url provided. Infrastructure check skipped. To enable: pass --health-url http://localhost:PORT/health. Retry config: count=${INFRA_RETRY_COUNT}, interval=${INFRA_RETRY_INTERVAL}s (profile=$PROFILE, loaded from profiles.json IMP-004)."

  jq -n \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    --slurpfile signals "$SIGNALS_TMP" \
    '{"$schema":"lane-signals-v1", lane:$lane, dimension:"QD1", probe_id:$probe,
      probe_version:$pver, profile:$profile, generated_at:$now, signals:$signals}'
  exit 0
fi

# ============================================================
# Retry logic (IMP-007 core): attempt INFRA_RETRY_COUNT times
# ============================================================
ATTEMPT=0
LAST_HTTP_CODE="000"
SUCCESS=false

while [ "$ATTEMPT" -lt "$INFRA_RETRY_COUNT" ]; do
  ATTEMPT=$((ATTEMPT + 1))
  # Note: curl -w "%{http_code}" always prints the code (000 when unreachable),
  # so we capture directly without || fallback to avoid double-000.
  set +e
  LAST_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time "$TIMEOUT_SEC" \
    --connect-timeout 5 \
    "$HEALTH_URL" 2>/dev/null)
  set -e
  # Normalise: empty or non-numeric → 000
  [[ "$LAST_HTTP_CODE" =~ ^[0-9]+$ ]] || LAST_HTTP_CODE="000"

  if echo "$LAST_HTTP_CODE" | grep -qE '^2'; then
    SUCCESS=true
    break
  fi

  if [ "$ATTEMPT" -lt "$INFRA_RETRY_COUNT" ]; then
    sleep "$INFRA_RETRY_INTERVAL"
  fi
done

# ============================================================
# Classify result
# ============================================================
if $SUCCESS; then
  _emit_signal "info" "none" \
    "Infra preflight: OK (HTTP $LAST_HTTP_CODE, attempt $ATTEMPT/$INFRA_RETRY_COUNT)" \
    "Infrastructure health check passed after $ATTEMPT attempt(s). Health URL: $HEALTH_URL returned HTTP $LAST_HTTP_CODE."
elif [ "$LAST_HTTP_CODE" = "000" ]; then
  _emit_signal "critical" "none" \
    "Infra preflight: UNREACHABLE after ${INFRA_RETRY_COUNT} retries" \
    "Infrastructure unreachable at $HEALTH_URL after ${INFRA_RETRY_COUNT} attempts (interval=${INFRA_RETRY_INTERVAL}s). Connection refused or timeout. Ensure service is running before wf-fix-bugs session."
else
  _emit_signal "high" "agent_fix" \
    "Infra preflight: UNHEALTHY (HTTP $LAST_HTTP_CODE after $INFRA_RETRY_COUNT retries)" \
    "Infrastructure returned HTTP $LAST_HTTP_CODE at $HEALTH_URL after $INFRA_RETRY_COUNT retry attempt(s). Service may be starting (cold start). Retry config: count=$INFRA_RETRY_COUNT, interval=${INFRA_RETRY_INTERVAL}s. Consider increasing --infra-retry-count."
fi

jq -n \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{"$schema":"lane-signals-v1", lane:$lane, dimension:"QD1", probe_id:$probe,
    probe_version:$pver, profile:$profile, generated_at:$now, signals:$signals}'

exit 0
