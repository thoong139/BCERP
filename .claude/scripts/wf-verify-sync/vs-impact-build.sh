#!/usr/bin/env bash
# Build verify-sync-impact.json artifact (schema verify-sync-impact-v1)
# Usage: bash vs-impact-build.sh <session_dir>
# Output: writes $SESSION_DIR/verify-sync-impact.json + prints JSON summary to stdout
# Requires: jq
set -euo pipefail
export MSYS_NO_PATHCONV=1  # FIX-E2E-1: prevent Git Bash path conversion on Windows
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

SESSION_DIR="${1:?Usage: vs-impact-build.sh <session_dir>}"
require_jq

SESSION_ID="${SESSION_DIR##*/}"
OUTPUT_FILE="$SESSION_DIR/verify-sync-impact.json"
STATUS_FILE="$SESSION_DIR/verify-sync-status.json"
CHECKPOINT_FILE="$SESSION_DIR/checkpoint.json"
LOCK_FILE="$SESSION_DIR/.session.lock"
TS=$(get_timestamp)

# ---------------------------------------------------------------------------
# Validate input
# ---------------------------------------------------------------------------
if [[ ! -f "$STATUS_FILE" ]]; then
  warn "verify-sync-status.json not found in $SESSION_DIR — impact artifact skipped"
  echo "{\"status\":\"skipped\",\"reason\":\"status_file_not_found\",\"session_id\":\"$SESSION_ID\"}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Read identity from lock file (preferred) or fall back to system
# ---------------------------------------------------------------------------
if [[ -f "$LOCK_FILE" ]]; then
  HOST=$(jq -r '.host // "unknown"' "$LOCK_FILE")
  VSUSER=$(jq -r '.user // "unknown"' "$LOCK_FILE")
else
  HOST=$(get_hostname)
  VSUSER=$(get_user)
fi

# ---------------------------------------------------------------------------
# Read summary from verify-sync-status.json
# Primary: sync_results (populated by Phase 6 Step 6.5).
# Fallback: phases.phase_2.* khi sync_results chưa được ghi (Step 6.5 bỏ sót).
# ---------------------------------------------------------------------------
SCOPE_TYPE=$(jq -r '.scope // "all"' "$STATUS_FILE")
SCOPE_NAME=$(jq -c '.scope_name // null' "$STATUS_FILE")  # FIX-E2E-2: -c not -rc; -r strips quotes → invalid JSON for --argjson
TOTAL=$(jq -r '.sync_results.total_req_ids // 0' "$STATUS_FILE")
if [[ "$TOTAL" -eq 0 ]]; then
  # Fallback: đọc từ phases nếu sync_results chưa được populate
  TOTAL=$(jq -r '.phases.phase_2.total_req_ids // .phases.phase_1.req_count // 0' "$STATUS_FILE")
  SYNC_RATE=$(jq -r '.phases.phase_2.sync_rate // 0' "$STATUS_FILE")
  COVERAGE_RATE=$(jq -r '.phases.phase_2.coverage_rate // .phases.phase_2.sync_rate // 0' "$STATUS_FILE")
  NOT_STARTED=$(jq -r '.phases.phase_2.gaps_count // 0' "$STATUS_FILE")
  IN_PROGRESS=$(jq -r '.phases.phase_2.partial_count // 0' "$STATUS_FILE")
  SKIPPED=0
  W001_COUNT=$(jq -r '.phases.phase_2.w001_count // 0' "$STATUS_FILE")
  ORPHAN_COUNT=$(jq -r '.phases.phase_2.orphan_count // 0' "$STATUS_FILE")
  IMPLEMENTED=$(jq -n \
    --argjson t "$TOTAL" --argjson ns "$NOT_STARTED" --argjson ip "$IN_PROGRESS" \
    '$t - $ns - $ip | if . < 0 then 0 else . end')
else
  IMPLEMENTED=$(jq -r '.sync_results.implemented // 0' "$STATUS_FILE")
  IN_PROGRESS=$(jq -r '.sync_results.in_progress // 0' "$STATUS_FILE")
  NOT_STARTED=$(jq -r '.sync_results.not_started // 0' "$STATUS_FILE")
  SKIPPED=$(jq -r '.sync_results.skipped_count // 0' "$STATUS_FILE")
  W001_COUNT=$(jq -r '.sync_results.w001_anomalies // 0' "$STATUS_FILE")
  ORPHAN_COUNT=$(jq -r '.sync_results.orphan_files // 0' "$STATUS_FILE")
  SYNC_RATE=$(jq -r '.sync_results.sync_rate_pct // 0' "$STATUS_FILE")
  COVERAGE_RATE=$(jq -r '.sync_results.coverage_rate_pct // 0' "$STATUS_FILE")
fi
HAS_FIX=$(jq -r '.has_fix_flag // false' "$STATUS_FILE")
FILES_FIXED=$(jq -r '.phases.phase_4.files_fixed // 0' "$STATUS_FILE")

# v3.3.0: Feature Completion context (cho PARTIAL_FEATURES verdict + priority override)
FEATURES_IN_PROGRESS=$(jq -r '.phases.phase_2.features_in_progress_count // 0' "$STATUS_FILE")
W003_COUNT=$(jq -r '.sync_results.w003_anomalies // .phases.phase_2.w003_count // 0' "$STATUS_FILE")

# v3.3.0: Priority override — check not_started REQ-IDs with critical/high priority
CRITICAL_HIGH_NOT_STARTED=$(jq -r '[.requirements[] | select(.impl_status=="not_started" and (.priority=="critical" or .priority=="high"))] | length' "$REGISTRY_PATH" 2>/dev/null || echo 0)

# Phase 3 UI coverage
P3_STATUS=$(jq -r '.phases.phase_3.status // "pending"' "$STATUS_FILE")
UI_SCREENS=$(jq -r '.phases.phase_3.total_screens // 0' "$STATUS_FILE")
UI_PCT_RAW=$(jq -r '.phases.phase_3.coverage_pct // "null"' "$STATUS_FILE")

# ---------------------------------------------------------------------------
# Read detailed anomaly arrays from checkpoint (graceful — may not exist)
# ---------------------------------------------------------------------------
W001_ARR="[]"
W002_ARR="[]"
W003_ARR="[]"
if [[ -f "$CHECKPOINT_FILE" ]]; then
  W001_RAW=$(jq -rc '.data_snapshot.w001_anomalies // []' "$CHECKPOINT_FILE")
  W002_RAW=$(jq -rc '.data_snapshot.w002_anomalies // []' "$CHECKPOINT_FILE")
  W003_RAW=$(jq -rc '.data_snapshot.w003_anomalies // []' "$CHECKPOINT_FILE")
  # Validate that these are JSON arrays
  if jq -e 'type == "array"' <<<"$W001_RAW" >/dev/null 2>&1; then
    W001_ARR="$W001_RAW"
  fi
  if jq -e 'type == "array"' <<<"$W002_RAW" >/dev/null 2>&1; then
    W002_ARR="$W002_RAW"
  fi
  if jq -e 'type == "array"' <<<"$W003_RAW" >/dev/null 2>&1; then
    W003_ARR="$W003_RAW"
  fi
fi
W002_COUNT=$(jq -r 'length' <<<"$W002_ARR")

# ---------------------------------------------------------------------------
# Compute verdict using jq arithmetic (avoids bc/python dependency)
# v3.3.0: PARTIAL_FEATURES level + priority override (critical/high not_started → NOT_READY)
# ---------------------------------------------------------------------------
VERDICT=$(jq -n \
  --argjson rate "$SYNC_RATE" \
  --argjson ns "$NOT_STARTED" \
  --argjson fiprogress "$FEATURES_IN_PROGRESS" \
  --argjson crithigh_ns "$CRITICAL_HIGH_NOT_STARTED" \
  'if ($crithigh_ns > 0) then "NOT_READY"
   elif ($rate >= 80) and ($ns == 0) and ($fiprogress == 0) then "READY"
   elif ($rate >= 80) and ($fiprogress > 0) then "PARTIAL_FEATURES"
   elif ($rate >= 60) then "PARTIAL"
   else "NOT_READY"
   end')
# Strip jq's surrounding quotes
VERDICT="${VERDICT//\"/}"

# ---------------------------------------------------------------------------
# UI coverage computed fields
# ---------------------------------------------------------------------------
UI_RAN="false"
UI_MATCHED=0
if [[ "$P3_STATUS" == "completed" ]]; then
  UI_RAN="true"
  if [[ "$UI_PCT_RAW" != "null" ]] && [[ "$UI_SCREENS" -gt 0 ]]; then
    UI_MATCHED=$(jq -n \
      --argjson screens "$UI_SCREENS" \
      --argjson pct "$UI_PCT_RAW" \
      '($screens * $pct / 100) | floor | tonumber')
  fi
fi

# ---------------------------------------------------------------------------
# Next recommended action
# MSYS_NO_PATHCONV=1 bắt buộc ở jq call phía dưới để tránh MSYS2 path conversion
# trên Windows Git Bash biến /wf-* thành C:/Program Files/Git/wf-*
# ---------------------------------------------------------------------------
case "$VERDICT" in
  READY)
    NEXT_SKILL='wf-prepare-deployment'
    NEXT_RATIONALE="Sync rate ${SYNC_RATE}% READY và không còn not_started. Khuyến nghị chạy /wf-prepare-deployment."
    BLOCKING='[]'
    ;;
  PARTIAL_FEATURES)
    NEXT_SKILL='wf-implement-feature'
    NEXT_RATIONALE="Sync rate ${SYNC_RATE}% PARTIAL_FEATURES — ${FEATURES_IN_PROGRESS} features còn in_progress. Hoàn thành features trước khi chạy /wf-prepare-deployment."
    BLOCKING=$(jq -c '. | if length > 3 then .[0:3] else . end' <<<"$W001_ARR")
    ;;
  PARTIAL)
    if [[ "$NOT_STARTED" -gt 0 ]]; then
      NEXT_SKILL='wf-implement-feature'
      NEXT_RATIONALE="Sync rate ${SYNC_RATE}% PARTIAL — ${NOT_STARTED} REQ-IDs chưa implement. Khuyến nghị /wf-implement-feature."
    else
      NEXT_SKILL='wf-fix-bugs'
      NEXT_RATIONALE="Sync rate ${SYNC_RATE}% PARTIAL — có W001/gaps cần xử lý. Khuyến nghị /wf-fix-bugs."
    fi
    BLOCKING=$(jq -c '. | if length > 3 then .[0:3] else . end' <<<"$W001_ARR")
    ;;
  NOT_READY)
    if [[ "$CRITICAL_HIGH_NOT_STARTED" -gt 0 ]]; then
      NEXT_SKILL='wf-implement-feature'
      NEXT_RATIONALE="Sync rate ${SYNC_RATE}% NOT_READY — ${CRITICAL_HIGH_NOT_STARTED} REQ-IDs critical/high chưa implement (priority override). Khuyến nghị /wf-implement-feature."
    else
      NEXT_SKILL='wf-implement-feature'
      NEXT_RATIONALE="Sync rate ${SYNC_RATE}% NOT_READY — ${NOT_STARTED} REQ-IDs chưa implement. Khuyến nghị /wf-implement-feature."
    fi
    BLOCKING=$(jq -c '. | if length > 5 then .[0:5] else . end' <<<"$W001_ARR")
    ;;
esac

# ---------------------------------------------------------------------------
# Build audit chain data_sources
# ---------------------------------------------------------------------------
DATA_SOURCES=$(jq -cn \
  --arg sf "$STATUS_FILE" \
  --arg rp "$REGISTRY_PATH" \
  '[$sf, $rp]')

# ---------------------------------------------------------------------------
# Read registry_changes from checkpoint (v4.0+ S3 F10 — was hardcoded [])
# ---------------------------------------------------------------------------
REGISTRY_CHANGES="[]"
if [[ -f "$CHECKPOINT_FILE" ]]; then
  RC_RAW=$(jq -rc '.data_snapshot.registry_changes // []' "$CHECKPOINT_FILE")
  if jq -e 'type == "array"' <<<"$RC_RAW" >/dev/null 2>&1; then
    REGISTRY_CHANGES="$RC_RAW"
  fi
fi

# ---------------------------------------------------------------------------
# Build final JSON artifact
# ---------------------------------------------------------------------------
jq -n \
  --arg schema "verify-sync-impact-v1" \
  --arg sid "$SESSION_ID" \
  --arg sdir "$SESSION_DIR" \
  --arg ts "$TS" \
  --arg host "$HOST" \
  --arg vsuser "$VSUSER" \
  --arg scope_type "$SCOPE_TYPE" \
  --argjson scope_name "$SCOPE_NAME" \
  --argjson total "$TOTAL" \
  --argjson impl "$IMPLEMENTED" \
  --argjson inp "$IN_PROGRESS" \
  --argjson ns "$NOT_STARTED" \
  --argjson skipped "$SKIPPED" \
  --argjson orphan "$ORPHAN_COUNT" \
  --argjson sync_rate "$SYNC_RATE" \
  --argjson cov_rate "$COVERAGE_RATE" \
  --arg verdict "$VERDICT" \
  --argjson w001c "$W001_COUNT" \
  --argjson w001arr "$W001_ARR" \
  --argjson w002c "$W002_COUNT" \
  --argjson w002arr "$W002_ARR" \
  --argjson w003c "$W003_COUNT" \
  --argjson w003arr "$W003_ARR" \
  --argjson ui_ran "$UI_RAN" \
  --argjson ui_screens "$UI_SCREENS" \
  --argjson ui_matched "$UI_MATCHED" \
  --argjson ui_pct "$([ "$UI_PCT_RAW" = "null" ] && echo "null" || echo "$UI_PCT_RAW")" \
  --argjson fix_applied "$HAS_FIX" \
  --argjson files_fixed "$FILES_FIXED" \
  --arg next_skill "$NEXT_SKILL" \
  --arg next_rationale "$NEXT_RATIONALE" \
  --argjson blocking "$BLOCKING" \
  --argjson registry_changes "$REGISTRY_CHANGES" \
  --argjson data_sources "$DATA_SOURCES" \
  '{
    "$schema": $schema,
    "schema_version": $schema,
    "session_id": $sid,
    "session_dir": $sdir,
    "generated_at": $ts,
    "host": $host,
    "user": $vsuser,
    "scope": {
      "type": $scope_type,
      "name": $scope_name
    },
    "verify_summary": {
      "total_req_ids": $total,
      "implemented": $impl,
      "in_progress": $inp,
      "not_started": $ns,
      "skipped": $skipped,
      "orphan_count": $orphan,
      "sync_rate_pct": $sync_rate,
      "coverage_rate_pct": $cov_rate,
      "verdict": $verdict
    },
    "warnings": {
      "w001_count": $w001c,
      "w001_anomalies": $w001arr,
      "w002_count": $w002c,
      "w002_anomalies": $w002arr,
      "w003_count": $w003c,
      "w003_anomalies": $w003arr
    },
    "registry_changes": $registry_changes,
    "ui_coverage": {
      "ran": $ui_ran,
      "total_screens": $ui_screens,
      "matched": $ui_matched,
      "coverage_pct": $ui_pct
    },
    "fix_log": {
      "applied": $fix_applied,
      "files_fixed": $files_fixed
    },
    "next_recommended_action": {
      "skill": ("/\($next_skill)"),
      "rationale": $next_rationale,
      "blocking_items": $blocking
    },
    "audit_chain": {
      "checksum_sha256": "pending",
      "data_sources": $data_sources
    }
  }' > "$OUTPUT_FILE"

# ---------------------------------------------------------------------------
# Compute audit checksum (cross-platform via vs-common.sh sha_hash)
# Strip checksum field before hashing, then write final
# ---------------------------------------------------------------------------
CHECKSUM=$(jq -Sc 'del(.audit_chain.checksum_sha256)' "$OUTPUT_FILE" \
  | if command -v sha256sum >/dev/null 2>&1; then
      sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
      shasum -a 256 | cut -d' ' -f1
    else
      cat | md5sum 2>/dev/null | cut -d' ' -f1 || echo "no-checksum"
    fi)

jq --arg cs "$CHECKSUM" '.audit_chain.checksum_sha256 = $cs' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"
mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo "{\"status\":\"built\",\"output\":\"$OUTPUT_FILE\",\"session_id\":\"$SESSION_ID\",\"verdict\":\"$VERDICT\",\"sync_rate\":$SYNC_RATE}"
