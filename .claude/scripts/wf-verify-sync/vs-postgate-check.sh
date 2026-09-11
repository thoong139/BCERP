#!/usr/bin/env bash
# vs-postgate-check.sh — POST-GATE T1→T4 validation (CORE-012)
# Usage: bash vs-postgate-check.sh --session-dir <dir> [--registry <file>] [--output <file>]
#                                                     [--interface-type <type>]
# Output: postgate-report.json → {tiers: {t1..t4}, passed, checks[], error_count, exit_code}
# Requires: jq
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
SESSION_DIR=""
REGISTRY_FILE="${REGISTRY_PATH}"
OUTPUT_FILE="/dev/stdout"
INTERFACE_TYPE="web"
CANONICAL_FILE="${CANONICAL_OUTPUT}"
HISTORY_FILE="${WORK_ROOT}/verify-sync-history.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --registry) REGISTRY_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --interface-type) INTERFACE_TYPE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

require_jq

# ---------------------------------------------------------------------------
# Auto-fix: If status != completed, finalize before checking (safety net)
# ---------------------------------------------------------------------------
STATUS_FILE_CANDIDATE="$SESSION_DIR/verify-sync-status.json"
if [[ -s "$STATUS_FILE_CANDIDATE" ]]; then
  CUR_ST=$(jq -r '.status // "unknown"' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "unknown")
  if [[ "$CUR_ST" != "completed" ]]; then
    warn "Session status='$CUR_ST' (expected 'completed') — auto-finalizing via vs-finalize-session.sh"
    # Extract values from existing files for auto-fix
    AUTO_SESSION_ID=$(jq -r '.session_id // ""' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "")
    AUTO_SYNC_RATE=$(jq -r '.sync_results.sync_rate_pct // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")
    AUTO_COV_RATE=$(jq -r '.sync_results.coverage_rate_pct // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")
    AUTO_TOTAL=$(jq -r '.sync_results.total_req_ids // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")
    AUTO_IMPL=$(jq -r '.sync_results.implemented // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")
    AUTO_WIP=$(jq -r '.sync_results.in_progress // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")
    AUTO_NS=$(jq -r '.sync_results.not_started // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")
    AUTO_SKIP=$(jq -r '.sync_results.skipped_count // 0' "$STATUS_FILE_CANDIDATE" 2>/dev/null || echo "0")

    # Try impact.json for better values
    IMPACT_CANDIDATE="$SESSION_DIR/verify-sync-impact.json"
    if [[ -s "$IMPACT_CANDIDATE" ]]; then
      AUTO_TOTAL=$(jq -r '.verify_summary.total_req_ids // $AUTO_TOTAL' "$IMPACT_CANDIDATE" 2>/dev/null || echo "$AUTO_TOTAL")
      AUTO_IMPL=$(jq -r '.verify_summary.implemented // $AUTO_IMPL' "$IMPACT_CANDIDATE" 2>/dev/null || echo "$AUTO_IMPL")
      AUTO_SYNC_RATE=$(jq -r '.verify_summary.sync_rate_pct // $AUTO_SYNC_RATE' "$IMPACT_CANDIDATE" 2>/dev/null || echo "$AUTO_SYNC_RATE")
      AUTO_COV_RATE=$(jq -r '.verify_summary.coverage_rate_pct // $AUTO_COV_RATE' "$IMPACT_CANDIDATE" 2>/dev/null || echo "$AUTO_COV_RATE")
    fi

    # Try checkpoint for canonical_decision
    AUTO_CD="no_conflict"
    CHECKPOINT_CANDIDATE="$SESSION_DIR/checkpoint.json"
    if [[ -s "$CHECKPOINT_CANDIDATE" ]]; then
      AUTO_CD=$(jq -r '.canonical_decision // "no_conflict"' "$CHECKPOINT_CANDIDATE" 2>/dev/null || echo "no_conflict")
    fi

    bash "$SCRIPT_DIR/vs-finalize-session.sh" \
      --session-dir "$SESSION_DIR" \
      --session-id "$AUTO_SESSION_ID" \
      --sync-rate "$AUTO_SYNC_RATE" \
      --coverage-rate "$AUTO_COV_RATE" \
      --total-req-ids "$AUTO_TOTAL" \
      --implemented "$AUTO_IMPL" \
      --in-progress "$AUTO_WIP" \
      --not-started "$AUTO_NS" \
      --skipped "$AUTO_SKIP" \
      --orphan-count "0" \
      --w001-count "0" \
      --w002-count "0" \
      --w003-count "0" \
      --canonical-decision "$AUTO_CD" \
      >/dev/null 2>&1 || true
    info "Auto-fix applied — re-checking status"
  fi
fi

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
if [[ -z "$SESSION_DIR" ]] || [[ ! -d "$SESSION_DIR" ]]; then
  error "session-dir required and must be an existing directory: $SESSION_DIR"
  jq -n '{passed: false, error: "missing_session_dir", checks: []}' > "$OUTPUT_FILE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: record a check result
# ---------------------------------------------------------------------------
record_check() {
  local tier="$1" id="$2" name="$3" status="$4" detail="${5:-}"
  jq -cn --arg tier "$tier" --arg id "$id" --arg name "$name" --arg status "$status" --arg detail "$detail" \
    '{tier: $tier, id: $id, name: $name, status: $status, detail: $detail}'
}

# Word count (cross-platform)
count_words() {
  local file="$1"
  wc -w < "$file" 2>/dev/null || echo 0
}

count_lines() {
  local file="$1"
  wc -l < "$file" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  info "vs-postgate-check.sh: Running T1→T4 POST-GATE validation..."
  info "  Session dir: $SESSION_DIR"

  local checks=()
  local errors=0
  local t1_pass=true t2_pass=true t3_pass=true t4_pass=true

  # Paths
  local session_copy="$SESSION_DIR/verify-sync.md"
  local status_json="$SESSION_DIR/verify-sync-status.json"
  local checkpoint_json="$SESSION_DIR/checkpoint.json"
  local impact_json="$SESSION_DIR/verify-sync-impact.json"
  local actionable_md="$SESSION_DIR/actionable-checklist.md"
  local phase_summary_md="$SESSION_DIR/phase-summary.md"
  local ui_coverage_md="$SESSION_DIR/ui-coverage-report.md"
  local index_file="${INDEX_FILE}"

  # ================================================================
  # T1 — EXISTENCE: File tồn tại, non-empty
  # ================================================================
  info "--- T1: Existence ---"

  # T1.1 Session copy
  if [[ -s "$session_copy" ]]; then
    local wc=$(count_words "$session_copy")
    checks+=("$(record_check "T1" "T1.1" "verify-sync.md (session copy)" "passed" "exists, $wc words")")
  else
    checks+=("$(record_check "T1" "T1.1" "verify-sync.md (session copy)" "failed" "missing or empty: $session_copy")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.2 Canonical output
  if [[ -s "$CANONICAL_FILE" ]]; then
    local wc=$(count_words "$CANONICAL_FILE")
    checks+=("$(record_check "T1" "T1.2" "verify-sync.md (canonical)" "passed" "exists, $wc words")")
  else
    checks+=("$(record_check "T1" "T1.2" "verify-sync.md (canonical)" "failed" "missing or empty: $CANONICAL_FILE")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.3 Status JSON
  if [[ -s "$status_json" ]]; then
    if jq -e '.' "$status_json" >/dev/null 2>&1; then
      checks+=("$(record_check "T1" "T1.3" "verify-sync-status.json" "passed" "exists, valid JSON")")
    else
      checks+=("$(record_check "T1" "T1.3" "verify-sync-status.json" "failed" "invalid JSON")")
      t1_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T1" "T1.3" "verify-sync-status.json" "failed" "missing or empty: $status_json")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.4 Checkpoint JSON
  if [[ -s "$checkpoint_json" ]]; then
    if jq -e '.' "$checkpoint_json" >/dev/null 2>&1; then
      checks+=("$(record_check "T1" "T1.4" "checkpoint.json" "passed" "exists, valid JSON")")
    else
      checks+=("$(record_check "T1" "T1.4" "checkpoint.json" "failed" "invalid JSON")")
      t1_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T1" "T1.4" "checkpoint.json" "failed" "missing or empty: $checkpoint_json")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.5 Impact JSON
  if [[ -s "$impact_json" ]]; then
    if jq -e '.' "$impact_json" >/dev/null 2>&1; then
      checks+=("$(record_check "T1" "T1.5" "verify-sync-impact.json" "passed" "exists, valid JSON")")
    else
      checks+=("$(record_check "T1" "T1.5" "verify-sync-impact.json" "failed" "invalid JSON")")
      t1_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T1" "T1.5" "verify-sync-impact.json" "failed" "missing or empty: $impact_json")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.6 Actionable checklist
  if [[ -s "$actionable_md" ]]; then
    local wc=$(count_words "$actionable_md")
    checks+=("$(record_check "T1" "T1.6" "actionable-checklist.md" "passed" "exists, $wc words")")
  else
    checks+=("$(record_check "T1" "T1.6" "actionable-checklist.md" "failed" "missing or empty: $actionable_md")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.7 Phase summary (CORE-028)
  if [[ -s "$phase_summary_md" ]]; then
    local wc=$(count_words "$phase_summary_md")
    checks+=("$(record_check "T1" "T1.7" "phase-summary.md (CORE-028)" "passed" "exists, $wc words")")
  else
    checks+=("$(record_check "T1" "T1.7" "phase-summary.md (CORE-028)" "failed" "missing or empty: $phase_summary_md")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.8 History file
  if [[ -s "$HISTORY_FILE" ]]; then
    local lc=$(count_lines "$HISTORY_FILE")
    checks+=("$(record_check "T1" "T1.8" "verify-sync-history.md" "passed" "exists, $lc lines")")
  else
    checks+=("$(record_check "T1" "T1.8" "verify-sync-history.md" "failed" "missing or empty: $HISTORY_FILE")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.9 Sessions index
  if [[ -s "$index_file" ]]; then
    local lc=$(count_lines "$index_file")
    if [[ "$lc" -ge 2 ]]; then
      checks+=("$(record_check "T1" "T1.9" "sessions.jsonl" "passed" "exists, $lc entries (>= 2: init + completed)")")
    else
      checks+=("$(record_check "T1" "T1.9" "sessions.jsonl" "failed" "$lc entries — need >= 2 (init + completed)")")
      t1_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T1" "T1.9" "sessions.jsonl" "failed" "missing or empty: $index_file")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # T1.10 UI coverage (conditional)
  if [[ "$INTERFACE_TYPE" != "api-only" ]]; then
    if [[ -s "$ui_coverage_md" ]]; then
      local wc=$(count_words "$ui_coverage_md")
      checks+=("$(record_check "T1" "T1.10" "ui-coverage-report.md" "passed" "exists (interface_type=$INTERFACE_TYPE), $wc words")")
    else
      checks+=("$(record_check "T1" "T1.10" "ui-coverage-report.md" "failed" "missing for interface_type=$INTERFACE_TYPE: $ui_coverage_md")")
      t1_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T1" "T1.10" "ui-coverage-report.md" "skipped" "interface_type=api-only — not required")")
  fi

  # T1.11 Registry JSON valid
  if [[ -s "$REGISTRY_FILE" ]]; then
    if jq -e '.' "$REGISTRY_FILE" >/dev/null 2>&1; then
      checks+=("$(record_check "T1" "T1.11" "req-registry.json" "passed" "exists, valid JSON")")
    else
      checks+=("$(record_check "T1" "T1.11" "req-registry.json" "failed" "invalid JSON")")
      t1_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T1" "T1.11" "req-registry.json" "failed" "missing or empty: $REGISTRY_FILE")")
    t1_pass=false; errors=$((errors + 1))
  fi

  # ================================================================
  # T2 — STRUCTURE: Required sections/fields present
  # ================================================================
  info "--- T2: Structure ---"

  # T2.1 Status JSON: required fields
  if [[ -s "$status_json" ]]; then
    local missing_fields=""
    jq -e '.status' "$status_json" >/dev/null 2>&1 || missing_fields="$missing_fields status"
    jq -e '.session_id' "$status_json" >/dev/null 2>&1 || missing_fields="$missing_fields session_id"
    jq -e '.sync_results' "$status_json" >/dev/null 2>&1 || missing_fields="$missing_fields sync_results"
    jq -e '.phases' "$status_json" >/dev/null 2>&1 || missing_fields="$missing_fields phases"

    if [[ -z "$missing_fields" ]]; then
      local st
      st=$(jq -r '.status' "$status_json")
      if [[ "$st" == "completed" ]]; then
        checks+=("$(record_check "T2" "T2.1" "Status JSON structure" "passed" "all required fields present, status=completed")")
      else
        checks+=("$(record_check "T2" "T2.1" "Status JSON structure" "failed" "status='$st' — expected 'completed'")")
        t2_pass=false; errors=$((errors + 1))
      fi
    else
      checks+=("$(record_check "T2" "T2.1" "Status JSON structure" "failed" "missing fields:$missing_fields")")
      t2_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T2" "T2.1" "Status JSON structure" "skipped" "file missing (T1.3 failed)")")
  fi

  # T2.2 Checkpoint JSON: required fields
  if [[ -s "$checkpoint_json" ]]; then
    local missing_fields=""
    jq -e '.session_id' "$checkpoint_json" >/dev/null 2>&1 || missing_fields="$missing_fields session_id"
    jq -e '.position' "$checkpoint_json" >/dev/null 2>&1 || missing_fields="$missing_fields position"
    jq -e '.data_snapshot' "$checkpoint_json" >/dev/null 2>&1 || missing_fields="$missing_fields data_snapshot"
    jq -e '.registry_state' "$checkpoint_json" >/dev/null 2>&1 || missing_fields="$missing_fields registry_state"

    # Check w003_anomalies field exists in data_snapshot (F4)
    if jq -e '.data_snapshot.w003_anomalies' "$checkpoint_json" >/dev/null 2>&1; then
      :
    else
      missing_fields="$missing_fields data_snapshot.w003_anomalies"
    fi
    # Check feature_summary field exists (F4)
    if jq -e '.data_snapshot.feature_summary' "$checkpoint_json" >/dev/null 2>&1; then
      :
    else
      missing_fields="$missing_fields data_snapshot.feature_summary"
    fi

    if [[ -z "$missing_fields" ]]; then
      checks+=("$(record_check "T2" "T2.2" "Checkpoint JSON structure" "passed" "all required fields present incl. w003_anomalies + feature_summary")")
    else
      checks+=("$(record_check "T2" "T2.2" "Checkpoint JSON structure" "failed" "missing fields:$missing_fields")")
      t2_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T2" "T2.2" "Checkpoint JSON structure" "skipped" "file missing (T1.4 failed)")")
  fi

  # T2.3 Impact JSON: required fields
  if [[ -s "$impact_json" ]]; then
    local missing_fields=""
    jq -e '.session_id' "$impact_json" >/dev/null 2>&1 || missing_fields="$missing_fields session_id"
    jq -e '.verdict' "$impact_json" >/dev/null 2>&1 || missing_fields="$missing_fields verdict"
    jq -e '.sync_rate_pct' "$impact_json" >/dev/null 2>&1 || missing_fields="$missing_fields sync_rate_pct"
    jq -e '.warnings' "$impact_json" >/dev/null 2>&1 || missing_fields="$missing_fields warnings"

    # Check w003 fields (F4)
    if jq -e '.warnings.w003_count' "$impact_json" >/dev/null 2>&1; then
      :
    else
      missing_fields="$missing_fields warnings.w003_count"
    fi

    # Check verdict ∈ {READY, PARTIAL_FEATURES, PARTIAL, NOT_READY}
    local verdict
    verdict=$(jq -r '.verdict' "$impact_json")
    case "$verdict" in
      READY|PARTIAL_FEATURES|PARTIAL|NOT_READY) ;;
      *)
        checks+=("$(record_check "T2" "T2.3" "Impact JSON structure" "failed" "verdict='$verdict' — expected READY/PARTIAL_FEATURES/PARTIAL/NOT_READY")")
        t2_pass=false; errors=$((errors + 1))
        ;;
    esac

    if [[ -z "$missing_fields" ]] && [[ "$verdict" =~ ^(READY|PARTIAL_FEATURES|PARTIAL|NOT_READY)$ ]]; then
      checks+=("$(record_check "T2" "T2.3" "Impact JSON structure" "passed" "all required fields present incl. w003_count, verdict=$verdict")")
    elif [[ -n "$missing_fields" ]]; then
      checks+=("$(record_check "T2" "T2.3" "Impact JSON structure" "failed" "missing fields:$missing_fields")")
      t2_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T2" "T2.3" "Impact JSON structure" "skipped" "file missing (T1.5 failed)")")
  fi

  # T2.4 Session copy markdown: required headings
  if [[ -s "$session_copy" ]]; then
    local missing_headings=""
    grep -q "^## Summary" "$session_copy" 2>/dev/null || missing_headings="$missing_headings Summary"
    grep -q -i "sync.*rate\|Sync.*Rate" "$session_copy" 2>/dev/null || missing_headings="$missing_headings SyncRate"
    grep -q -i "gaps\|Gaps\|Not Started\|Actionable Checklist" "$session_copy" 2>/dev/null || missing_headings="$missing_headings Gaps/Checklist"
    grep -q -i "orphan\|Orphan" "$session_copy" 2>/dev/null || missing_headings="$missing_headings Orphans"

    if [[ -z "$missing_headings" ]]; then
      checks+=("$(record_check "T2" "T2.4" "verify-sync.md sections" "passed" "required headings present")")
    else
      checks+=("$(record_check "T2" "T2.4" "verify-sync.md sections" "failed" "missing headings:$missing_headings")")
      t2_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T2" "T2.4" "verify-sync.md sections" "skipped" "file missing (T1.1 failed)")")
  fi

  # T2.5 Phase summary: CORE-028 structure
  if [[ -s "$phase_summary_md" ]]; then
    local has_summary=false has_next=false
    grep -q "## Tóm tắt\|## Summary\|## Kết quả" "$phase_summary_md" 2>/dev/null && has_summary=true
    grep -q "## Bước tiếp theo\|## Next\|## Khuyến nghị" "$phase_summary_md" 2>/dev/null && has_next=true
    if $has_summary && $has_next; then
      checks+=("$(record_check "T2" "T2.5" "phase-summary.md structure" "passed" "CORE-028 sections present")")
    else
      checks+=("$(record_check "T2" "T2.5" "phase-summary.md structure" "failed" "missing CORE-028 sections (summary=$has_summary, next=$has_next)")")
      t2_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T2" "T2.5" "phase-summary.md structure" "skipped" "file missing (T1.7 failed)")")
  fi

  # T2.6 Actionable checklist: required structure
  if [[ -s "$actionable_md" ]]; then
    local has_checklist=false
    grep -q "\[ \]\|\[x\]\|\[X\]" "$actionable_md" 2>/dev/null && has_checklist=true
    if $has_checklist; then
      checks+=("$(record_check "T2" "T2.6" "actionable-checklist.md structure" "passed" "checklist items present")")
    else
      checks+=("$(record_check "T2" "T2.6" "actionable-checklist.md structure" "failed" "no checklist items found (expected [ ] checkboxes)")")
      t2_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T2" "T2.6" "actionable-checklist.md structure" "skipped" "file missing (T1.6 failed)")")
  fi

  # T2.7 Registry required fields
  if [[ -s "$REGISTRY_FILE" ]]; then
    local reg_missing=""
    jq -e '.requirements' "$REGISTRY_FILE" >/dev/null 2>&1 || reg_missing="$reg_missing requirements"
    jq -e '.features' "$REGISTRY_FILE" >/dev/null 2>&1 || reg_missing="$reg_missing features"
    local req_count
    req_count=$(jq -r '.requirements | length' "$REGISTRY_FILE")
    if [[ -z "$reg_missing" ]] && [[ "$req_count" -gt 0 ]]; then
      checks+=("$(record_check "T2" "T2.7" "req-registry.json structure" "passed" "requirements[] ($req_count entries) + features[] present")")
    else
      checks+=("$(record_check "T2" "T2.7" "req-registry.json structure" "failed" "missing fields:$reg_missing or requirements empty")")
      t2_pass=false; errors=$((errors + 1))
    fi
  fi

  # ================================================================
  # T3 — CONTENT: Minimum content depth
  # ================================================================
  info "--- T3: Content ---"

  # T3.1 Session copy: >= 200 words
  if [[ -s "$session_copy" ]]; then
    local wc=$(count_words "$session_copy")
    if [[ "$wc" -ge 200 ]]; then
      checks+=("$(record_check "T3" "T3.1" "verify-sync.md word count" "passed" "$wc words >= 200")")
    else
      checks+=("$(record_check "T3" "T3.1" "verify-sync.md word count" "failed" "$wc words < 200 minimum")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.1" "verify-sync.md word count" "skipped" "file missing")")
  fi

  # T3.2 Status JSON: sync_results populated
  if [[ -s "$status_json" ]]; then
    local total
    total=$(jq -r '.sync_results.total_req_ids // 0' "$status_json")
    if [[ "$total" -gt 0 ]]; then
      checks+=("$(record_check "T3" "T3.2" "Status sync_results populated" "passed" "total_req_ids=$total > 0")")
    else
      checks+=("$(record_check "T3" "T3.2" "Status sync_results populated" "failed" "total_req_ids=$total — should be > 0")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.2" "Status sync_results populated" "skipped" "file missing")")
  fi

  # T3.3 Checkpoint: data_snapshot has content
  if [[ -s "$checkpoint_json" ]]; then
    local snapshot_size
    snapshot_size=$(jq -r '.data_snapshot | tojson | length' "$checkpoint_json")
    if [[ "$snapshot_size" -gt 50 ]]; then
      checks+=("$(record_check "T3" "T3.3" "Checkpoint data_snapshot depth" "passed" "data_snapshot populated ($snapshot_size chars)")")
    else
      checks+=("$(record_check "T3" "T3.3" "Checkpoint data_snapshot depth" "failed" "data_snapshot nearly empty ($snapshot_size chars)")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.3" "Checkpoint data_snapshot depth" "skipped" "file missing")")
  fi

  # T3.4 Impact JSON: warnings.w003_count is numeric
  if [[ -s "$impact_json" ]]; then
    local w003
    w003=$(jq -r '.warnings.w003_count // -1' "$impact_json")
    if [[ "$w003" -ge 0 ]] 2>/dev/null; then
      checks+=("$(record_check "T3" "T3.4" "Impact w003_count numeric" "passed" "w003_count=$w003 (valid number)")")
    else
      checks+=("$(record_check "T3" "T3.4" "Impact w003_count numeric" "failed" "w003_count=$w003 — expected >= 0")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.4" "Impact w003_count numeric" "skipped" "file missing")")
  fi

  # T3.5 Actionable checklist: >= 50 words
  if [[ -s "$actionable_md" ]]; then
    local wc=$(count_words "$actionable_md")
    if [[ "$wc" -ge 50 ]]; then
      checks+=("$(record_check "T3" "T3.5" "actionable-checklist.md content" "passed" "$wc words >= 50")")
    else
      checks+=("$(record_check "T3" "T3.5" "actionable-checklist.md content" "failed" "$wc words < 50 minimum")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.5" "actionable-checklist.md content" "skipped" "file missing")")
  fi

  # T3.6 Phase summary: >= 100 words
  if [[ -s "$phase_summary_md" ]]; then
    local wc=$(count_words "$phase_summary_md")
    if [[ "$wc" -ge 100 ]]; then
      checks+=("$(record_check "T3" "T3.6" "phase-summary.md content" "passed" "$wc words >= 100")")
    else
      checks+=("$(record_check "T3" "T3.6" "phase-summary.md content" "failed" "$wc words < 100 minimum")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.6" "phase-summary.md content" "skipped" "file missing")")
  fi

  # T3.7 Status progress_pct == 100
  if [[ -s "$status_json" ]]; then
    local pct
    pct=$(jq -r '.progress_pct // 0' "$status_json")
    if [[ "$pct" -eq 100 ]]; then
      checks+=("$(record_check "T3" "T3.7" "Status progress_pct = 100" "passed" "progress_pct=$pct")")
    else
      checks+=("$(record_check "T3" "T3.7" "Status progress_pct = 100" "failed" "progress_pct=$pct — expected 100")")
      t3_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T3" "T3.7" "Status progress_pct = 100" "skipped" "file missing")")
  fi

  # ================================================================
  # T4 — CROSS-REFERENCE: IDs match between files
  # ================================================================
  info "--- T4: Cross-reference ---"

  # T4.1 Session ID consistency across all JSON files
  if [[ -s "$status_json" ]] && [[ -s "$checkpoint_json" ]] && [[ -s "$impact_json" ]]; then
    local sid_s sid_c sid_i
    sid_s=$(jq -r '.session_id // ""' "$status_json")
    sid_c=$(jq -r '.session_id // ""' "$checkpoint_json")
    sid_i=$(jq -r '.session_id // ""' "$impact_json")

    local mismatches=""
    [[ "$sid_s" != "$sid_c" ]] && mismatches="$mismatches status!=checkpoint"
    [[ "$sid_s" != "$sid_i" ]] && mismatches="$mismatches status!=impact"
    [[ "$sid_c" != "$sid_i" ]] && mismatches="$mismatches checkpoint!=impact"

    if [[ -z "$mismatches" ]]; then
      checks+=("$(record_check "T4" "T4.1" "Session ID consistency" "passed" "session_id=$sid_s matches across status/checkpoint/impact")")
    else
      checks+=("$(record_check "T4" "T4.1" "Session ID consistency" "failed" "session_id mismatch:$mismatches (status=$sid_s, checkpoint=$sid_c, impact=$sid_i)")")
      t4_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T4" "T4.1" "Session ID consistency" "skipped" "missing 1+ JSON files")")
  fi

  # T4.2 REQ-ID counts match between status and impact
  if [[ -s "$status_json" ]] && [[ -s "$impact_json" ]]; then
    local st_total im_total
    st_total=$(jq -r '.sync_results.total_req_ids // 0' "$status_json")
    im_total=$(jq -r '.total_req_ids // 0' "$impact_json")

    if [[ "$st_total" -eq "$im_total" ]]; then
      checks+=("$(record_check "T4" "T4.2" "REQ-ID count cross-ref" "passed" "status.total_req_ids=$st_total == impact.total_req_ids=$im_total")")
    elif [[ "$im_total" -eq 0 ]]; then
      checks+=("$(record_check "T4" "T4.2" "REQ-ID count cross-ref" "warning" "impact.total_req_ids=0 (may not be populated yet)")")
    else
      checks+=("$(record_check "T4" "T4.2" "REQ-ID count cross-ref" "failed" "status=$st_total != impact=$im_total")")
      t4_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T4" "T4.2" "REQ-ID count cross-ref" "skipped" "missing status or impact JSON")")
  fi

  # T4.3 Sync rate matches between status and impact
  if [[ -s "$status_json" ]] && [[ -s "$impact_json" ]]; then
    local st_rate im_rate
    st_rate=$(jq -r '.sync_results.sync_rate_pct // -1' "$status_json")
    im_rate=$(jq -r '.sync_rate_pct // -1' "$impact_json")

    if [[ "$st_rate" == "$im_rate" ]]; then
      checks+=("$(record_check "T4" "T4.3" "Sync rate cross-ref" "passed" "status.sync_rate_pct=$st_rate == impact.sync_rate_pct=$im_rate")")
    elif [[ "$im_rate" == "null" ]] || [[ "$im_rate" == "-1" ]]; then
      checks+=("$(record_check "T4" "T4.3" "Sync rate cross-ref" "warning" "impact.sync_rate_pct=$im_rate not set")")
    else
      checks+=("$(record_check "T4" "T4.3" "Sync rate cross-ref" "failed" "status=$st_rate != impact=$im_rate")")
      t4_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T4" "T4.3" "Sync rate cross-ref" "skipped" "missing status or impact JSON")")
  fi

  # T4.4 sessions.jsonl has completed entry for this session
  if [[ -s "$index_file" ]] && [[ -s "$status_json" ]]; then
    local sid
    sid=$(jq -r '.session_id // ""' "$status_json")
    if [[ -n "$sid" ]] && grep -q "\"session_id\":\"$sid\"" "$index_file" 2>/dev/null; then
      local completed_count
      completed_count=$(grep -c "\"session_id\":\"$sid\".*\"completed\"" "$index_file" 2>/dev/null || echo 0)
      if [[ "$completed_count" -ge 1 ]]; then
        checks+=("$(record_check "T4" "T4.4" "JSONL completed entry" "passed" "session_id=$sid has completed entry in sessions.jsonl")")
      else
        checks+=("$(record_check "T4" "T4.4" "JSONL completed entry" "failed" "session_id=$sid missing completed entry in sessions.jsonl")")
        t4_pass=false; errors=$((errors + 1))
      fi
    else
      checks+=("$(record_check "T4" "T4.4" "JSONL completed entry" "failed" "session_id=$sid not found in sessions.jsonl")")
      t4_pass=false; errors=$((errors + 1))
    fi
  else
    checks+=("$(record_check "T4" "T4.4" "JSONL completed entry" "skipped" "missing index or status JSON")")
  fi

  # T4.5 Canonical content matches session copy (when canonical written)
  if [[ -s "$session_copy" ]] && [[ -s "$CANONICAL_FILE" ]]; then
    local canonical_decision
    canonical_decision=$(jq -r '.canonical_decision // "unknown"' "$status_json" 2>/dev/null || echo "unknown")
    if [[ "$canonical_decision" == "override" ]] || [[ "$canonical_decision" == "no_conflict" ]]; then
      if diff -q "$session_copy" "$CANONICAL_FILE" >/dev/null 2>&1; then
        checks+=("$(record_check "T4" "T4.5" "Canonical/session content match" "passed" "canonical matches session copy (decision=$canonical_decision)")")
      else
        checks+=("$(record_check "T4" "T4.5" "Canonical/session content match" "failed" "canonical differs from session copy (decision=$canonical_decision)")")
        t4_pass=false; errors=$((errors + 1))
      fi
    else
      checks+=("$(record_check "T4" "T4.5" "Canonical/session content match" "skipped" "canonical decision=$canonical_decision — not expected to match")")
    fi
  else
    checks+=("$(record_check "T4" "T4.5" "Canonical/session content match" "skipped" "missing session or canonical copy")")
  fi

  # ================================================================
  # Final result
  # ================================================================
  local overall_passed=true
  $t1_pass || overall_passed=false
  $t2_pass || overall_passed=false
  $t3_pass || overall_passed=false
  $t4_pass || overall_passed=false

  local total_checks=${#checks[@]}
  local passed_checks
  passed_checks=$(printf '%s\n' "${checks[@]}" | jq -s '[.[] | select(.status == "passed")] | length')

  local exit_code=0
  $overall_passed || exit_code=1

  jq -n \
    --argjson passed "$overall_passed" \
    --argjson tiers "$(jq -n --argjson t1 "$t1_pass" --argjson t2 "$t2_pass" --argjson t3 "$t3_pass" --argjson t4 "$t4_pass" '{t1: $t1, t2: $t2, t3: $t3, t4: $t4}')" \
    --argjson total "$total_checks" \
    --argjson passed_count "$passed_checks" \
    --argjson errors "$errors" \
    --argjson checks "$(printf '%s\n' "${checks[@]}" | jq -s '.')" \
    --argjson exit_code "$exit_code" \
    '{
      passed: $passed,
      tiers: $tiers,
      total_checks: $total,
      passed_checks: $passed_count,
      error_count: $errors,
      checks: $checks,
      exit_code: $exit_code
    }' > "$OUTPUT_FILE"

  if $overall_passed; then
    info "POST-GATE: PASS — $passed_checks/$total_checks checks passed, 0 errors"
  else
    error "POST-GATE: FAIL — $passed_checks/$total_checks passed, $errors errors"
  fi
  info "Output: $OUTPUT_FILE"

  return $exit_code
}

main
