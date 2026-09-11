#!/usr/bin/env bash
# wf-fix-impact-builder.sh — Build fix-impact.json (schema fix-impact-v1) cho POST-GATE wf-fix-bugs (v7.4.0 S7)
#
# Usage:
#   wf-fix-impact-builder.sh --session-dir <path> [--output <path>]
#
# Inputs (read-only):
#   $SESSION_DIR/fix-status.json
#   $SESSION_DIR/issue-registry.json
#   $SESSION_DIR/fix-log.json
#   $SESSION_DIR/phase4-find-bugs/lanes/QD*/lane-status.json
#   git (optional: git diff HEAD~1..HEAD --stat)
#   .mc-data/docs/_meta/req-registry.json (optional: registry diff vs HEAD~1)
#
# Output:
#   $SESSION_DIR/fix-impact.json (default) or --output path
#
# Exit codes:
#   0 — success (file generated, schema valid)
#   1 — invalid args / session-dir not found
#   2 — required input missing (fix-status.json or issue-registry.json)
#   3 — JSON build failure
#
# Graceful degrade: missing optional inputs (fix-log empty, lane-status missing, git unavailable)
# → default values, KHÔNG fail. Logged via stderr WARN.
#
# Stub fallback (v8.2+): khi exit 2 hoặc exit 3, builder vẫn write stub file
# với schema fix-impact-v1 + status="degraded" + degraded_reason. Downstream consumers
# (wf-verify-sync, wf-prepare-deployment) PHẢI check `.status` field — nếu "degraded" →
# block consume + thông báo user manual review.

set -euo pipefail

# Source common helpers (atomic_write_json, json_escape, iso_now)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# ============================================================
# ARG PARSING
# ============================================================
SESSION_DIR=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --output)      OUTPUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "ERROR: --session-dir required" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: session-dir not found: $SESSION_DIR" >&2; exit 1; }

OUTPUT="${OUTPUT:-$SESSION_DIR/fix-impact.json}"

FIX_STATUS="$SESSION_DIR/fix-status.json"
ISSUE_REGISTRY="$SESSION_DIR/issue-registry.json"
FIX_LOG="$SESSION_DIR/fix-log.json"
LANES_DIR="$SESSION_DIR/phase4-find-bugs/lanes"

# ============================================================
# STUB FALLBACK helper (v8.2+)
# Write degraded stub khi builder không hoàn thành full assembly.
# Downstream (wf-verify-sync, wf-prepare-deployment) PHẢI kiểm `.status == "degraded"`.
# ============================================================
write_degraded_stub() {
  local reason="$1"
  local sid="$(basename "$SESSION_DIR")"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")"
  jq -n \
    --arg sid "$sid" \
    --arg reason "$reason" \
    --arg ts "$ts" \
    '{
      "$schema": "fix-impact-v1",
      status: "degraded",
      degraded_reason: $reason,
      session_id: $sid,
      generated_at: $ts,
      generator: "wf-fix-impact-builder.sh (stub fallback)",
      next_recommended_action: {
        skill: "manual-review",
        rationale: ("fix-impact-builder failed: " + $reason + " — please inspect fix-status.json + fix-report.md manually before downstream skills."),
        blocking_items: [{type: "builder_failed", count: 1, note: $reason}]
      }
    }' > "$OUTPUT" 2>/dev/null || {
      echo "ERROR: even stub write failed for $OUTPUT" >&2
      return 1
    }
  echo "STUB: wrote degraded fix-impact.json (reason: $reason) → $OUTPUT" >&2
}

# Required inputs — emit stub trước khi exit để downstream luôn có file đọc
if [ ! -s "$FIX_STATUS" ]; then
  echo "ERROR: fix-status.json missing or empty: $FIX_STATUS" >&2
  write_degraded_stub "fix-status.json missing or empty" || true
  exit 2
fi
if [ ! -s "$ISSUE_REGISTRY" ]; then
  echo "ERROR: issue-registry.json missing or empty: $ISSUE_REGISTRY" >&2
  write_degraded_stub "issue-registry.json missing or empty" || true
  exit 2
fi

# Optional: fix-log (graceful — entries=[] nếu thiếu)
if [ ! -s "$FIX_LOG" ]; then
  echo "WARN: fix-log.json missing/empty, treating as empty entries[]" >&2
  FIX_LOG_JSON='{"entries":[]}'
else
  FIX_LOG_JSON=$(cat "$FIX_LOG")
fi

# ============================================================
# EXTRACT SCOPE
# ============================================================
SCOPE_TYPE=$(jq -r '.flags.scope // "all"' "$FIX_STATUS")
SCOPE_NAME=$(jq -r '.flags.name // ""' "$FIX_STATUS")
SCOPE_SYSTEM=""
# Nếu scope=module và name có dạng "system/module", split
if [ "$SCOPE_TYPE" = "module" ] && [[ "$SCOPE_NAME" == */* ]]; then
  SCOPE_SYSTEM="${SCOPE_NAME%%/*}"
  SCOPE_NAME="${SCOPE_NAME#*/}"
fi

SESSION_ID=$(basename "$SESSION_DIR")

# ============================================================
# COMPUTE fix_summary
# ============================================================
# F3 (SB-05) — Apply F26 pattern: primary count từ fix-log entries length (mỗi entry = 1 fix
# theo phase3-batch1.md §3.1.4 Data Update Protocol B); fallback registry dual-field
# (.status hoặc .fix_status) vì phase3-batch1.md/phase5-loop.md set `.status="fixed"`
# nhưng evals/legacy data dùng `.fix_status`.
TOTAL_ISSUES=$(jq '.issues | length // 0' "$ISSUE_REGISTRY")
# F3 BUG-01 fix: chỉ fallback khi fix-log thực sự RỖNG (không có .entries hoặc parse fail).
# Truoc day: fallback khi FIXED==0, dan den inflate count khi fix-log co entries deferred/skipped.
# Phan biet: jq '.entries' tra ve null (no field) vs [] (empty array).
HAS_FIX_LOG_ENTRIES=$(jq -r '(.entries // null) != null' <<< "$FIX_LOG_JSON" 2>/dev/null || echo "false")
FIX_LOG_ENTRIES_COUNT=$(jq '[.entries[]?] | length' <<< "$FIX_LOG_JSON" 2>/dev/null || echo 0)
if [ "$HAS_FIX_LOG_ENTRIES" = "true" ]; then
  # fix-log valid và có .entries (kể cả rỗng) → count entries (1 entry = 1 fix)
  FIXED="$FIX_LOG_ENTRIES_COUNT"
else
  # fix-log thực sự rỗng/missing → fallback registry dual-field
  FIXED=$(jq '[.issues[] | select((.status // "") == "fixed" or (.fix_status // "") == "fixed" or (.fix_status // "") == "completed")] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
fi
DEFERRED=$(jq '[.issues[] | select((.status // "") == "deferred" or (.fix_status // "") == "deferred")] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
ESCALATED=$(jq '[.issues[] | select((.status // "") == "escalated" or (.fix_status // "") == "escalated")] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
SKIPPED=$(jq '[.issues[] | select((.status // "") == "skipped" or (.fix_status // "") == "skipped")] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)

# verify_iterations từ fix-status.phases.phase_5.loop_state.current_iteration (S2 SSOT)
VERIFY_ITERATIONS=$(jq '.phases.phase_5.loop_state.current_iteration // 0' "$FIX_STATUS" 2>/dev/null || echo 0)

# ============================================================
# COMPUTE by_dimension (7 lanes)
# ============================================================
build_dim_stats() {
  local qd="$1"
  local detected fixed deferred escalated skipped
  # F3 (SB-05) — chấp nhận cả .status và .fix_status (dual-field) cho consistency với
  # phase3-batch1.md §3.1.4 (canonical .status="fixed") và evals/legacy (.fix_status).
  detected=$(jq --arg qd "$qd" '[.issues[] | select(.dimension == $qd)] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
  fixed=$(jq --arg qd "$qd" '[.issues[] | select(.dimension == $qd and ((.status // "") == "fixed" or (.fix_status // "") == "fixed" or (.fix_status // "") == "completed"))] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
  deferred=$(jq --arg qd "$qd" '[.issues[] | select(.dimension == $qd and ((.status // "") == "deferred" or (.fix_status // "") == "deferred"))] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
  escalated=$(jq --arg qd "$qd" '[.issues[] | select(.dimension == $qd and ((.status // "") == "escalated" or (.fix_status // "") == "escalated"))] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
  skipped=$(jq --arg qd "$qd" '[.issues[] | select(.dimension == $qd and ((.status // "") == "skipped" or (.fix_status // "") == "skipped"))] | length' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)

  jq -nc \
    --argjson det "$detected" --argjson fix "$fixed" \
    --argjson def "$deferred" --argjson esc "$escalated" --argjson skp "$skipped" \
    '{detected: $det, fixed: $fix, deferred: $def, escalated: $esc, skipped: $skp}'
}

# CRIT-3 fix: loop QD1-QD11 thay vi hardcode QD1-QD8 (root cause v9.0.0 fantasy bug)
# Khi them dimension moi (vd: QD11), chi can them vao DIMENSIONS array.
DIMENSIONS=(QD1 QD2 QD3 QD4 QD5 QD6 QD7 QD8 QD9 QD10 QD11)
BY_DIMENSION_JSON='{}'
for qd in "${DIMENSIONS[@]}"; do
  dim_stats=$(build_dim_stats "$qd") || dim_stats='{"detected":0,"fixed":0,"deferred":0,"escalated":0,"skipped":0}'
  BY_DIMENSION_JSON=$(jq --arg key "$qd" --argjson val "$dim_stats" '. + {($key): $val}' <<< "$BY_DIMENSION_JSON") || {
    echo "ERROR: build by_dimension failed at $qd" >&2
    write_degraded_stub "by_dimension build failed at $qd" || true
    exit 3
  }
done

# ============================================================
# COMPUTE affected_artifacts (code_files, feature_specs, ux_specs, registry_changes)
# ============================================================
# code_files: aggregate from fix-log entries[].files_modified[] + .files_created[]
CODE_FILES=$(jq -c '
  [
    .entries[] |
    (.files_modified // []) + (.files_created // []) | .[] |
    select(. != null and . != "")
  ] | unique | map({
    path: .,
    req_ids: [],
    feat_ids: [],
    issues_addressed: [],
    modification_type: "edit"
  })
' <<< "$FIX_LOG_JSON" 2>/dev/null || echo '[]')

# feature_specs_updated: filter code_files by phase2-features path
FEATURE_SPECS=$(jq -c '
  [
    .entries[] |
    (.files_modified // []) + (.files_created // []) | .[] |
    select(. != null and (test(".mc-data/docs/phase2-features/")))
  ] | unique | map({
    path: .,
    change_type: "behavior_clarification",
    issues: []
  })
' <<< "$FIX_LOG_JSON" 2>/dev/null || echo '[]')

# ux_specs_updated: filter by phase4-ux path
UX_SPECS=$(jq -c '
  [
    .entries[] |
    (.files_modified // []) + (.files_created // []) | .[] |
    select(. != null and (test(".mc-data/docs/phase4-ux/")))
  ] | unique | map({
    path: .,
    change_type: "stub",
    issues: []
  })
' <<< "$FIX_LOG_JSON" 2>/dev/null || echo '[]')

# registry_changes: scan issue-registry for impl_status changes (best-effort)
REGISTRY_CHANGES=$(jq -c '
  [
    .issues[] |
    select(.registry_change != null) |
    {
      req_id: (.req_id // .registry_change.req_id // null),
      field: (.registry_change.field // "impl_status"),
      before: (.registry_change.before // null),
      after: (.registry_change.after // null),
      issue_ref: (.id // .issue_id // null)
    } |
    select(.req_id != null)
  ]
' "$ISSUE_REGISTRY" 2>/dev/null || echo '[]')

REGISTRY_CHANGES_COUNT=$(jq 'length' <<< "$REGISTRY_CHANGES")

# ============================================================
# COMPUTE verify_evidence (per-issue — D4 field)
# ============================================================
VERIFY_EVIDENCE=$(jq -c '
  [
    .entries[] |
    select(.verify_results != null or .verified == true) |
    {
      issue_id: (.issue_id // null),
      verify_iteration: (.iteration // 0),
      method: (.verify_method // "agent"),
      agent: (.agent // null),
      result: (.verify_results.status // .verify_status // "PASS"),
      evidence_files: (.evidence_files // []),
      regression_tests: (.regression_tests // [])
    } |
    select(.issue_id != null)
  ]
' <<< "$FIX_LOG_JSON" 2>/dev/null || echo '[]')

# ============================================================
# COMPUTE regression_check (D4 field) — aggregate verify_results.tests_*
# ============================================================
TESTS_RUN=$(jq '[.entries[] | (.verify_results.tests_run // 0)] | add // 0' <<< "$FIX_LOG_JSON" 2>/dev/null || echo 0)
TESTS_PASSED=$(jq '[.entries[] | (.verify_results.tests_passed // 0)] | add // 0' <<< "$FIX_LOG_JSON" 2>/dev/null || echo 0)
TESTS_FAILED=$(jq '[.entries[] | (.verify_results.tests_failed // 0)] | add // 0' <<< "$FIX_LOG_JSON" 2>/dev/null || echo 0)
TESTS_FAILED_IDS=$(jq -c '[.entries[] | (.verify_results.tests_failed_ids // [])[]] | unique' <<< "$FIX_LOG_JSON" 2>/dev/null || echo '[]')
COVERAGE_DELTA=$(jq '[.entries[] | (.verify_results.coverage_delta_pct // null) | select(. != null)] | (if length > 0 then (add / length) else null end)' <<< "$FIX_LOG_JSON" 2>/dev/null || echo "null")

REGRESSION_CHECK=$(jq -nc \
  --argjson run "$TESTS_RUN" \
  --argjson pass "$TESTS_PASSED" \
  --argjson fail "$TESTS_FAILED" \
  --argjson fail_ids "$TESTS_FAILED_IDS" \
  --argjson cov "$COVERAGE_DELTA" \
  '{
    tests_run: $run,
    tests_passed: $pass,
    tests_failed: $fail,
    tests_failed_ids: $fail_ids,
    coverage_delta_pct: $cov
  }')

# ============================================================
# COMPUTE audit_chain.checksum_sha256 (D4 field)
# Reproducible: sort entries by issue_id, jq -S compact (no whitespace), sha256
# ============================================================
FIX_LOG_ENTRIES_COUNT=$(jq '.entries | length' <<< "$FIX_LOG_JSON")
FIRST_ENTRY_ID="null"
LAST_ENTRY_ID="null"
CHECKSUM_SHA256="0000000000000000000000000000000000000000000000000000000000000000"

if [ "$FIX_LOG_ENTRIES_COUNT" -gt 0 ]; then
  FIRST_ENTRY_ID=$(jq -r '.entries | sort_by(.issue_id // "") | .[0].issue_id // "null"' <<< "$FIX_LOG_JSON")
  LAST_ENTRY_ID=$(jq -r '.entries | sort_by(.issue_id // "") | .[-1].issue_id // "null"' <<< "$FIX_LOG_JSON")
  # Sort entries by issue_id, compact JSON, sha256
  CANONICAL=$(jq -Sc '.entries | sort_by(.issue_id // "")' <<< "$FIX_LOG_JSON")
  CHECKSUM_SHA256=$(printf '%s' "$CANONICAL" | sha256sum 2>/dev/null | awk '{print $1}')
  if [ -z "$CHECKSUM_SHA256" ]; then
    # macOS fallback
    CHECKSUM_SHA256=$(printf '%s' "$CANONICAL" | shasum -a 256 2>/dev/null | awk '{print $1}')
  fi
fi

AUDIT_CHAIN=$(jq -nc \
  --argjson n "$FIX_LOG_ENTRIES_COUNT" \
  --arg first "$FIRST_ENTRY_ID" \
  --arg last "$LAST_ENTRY_ID" \
  --arg cs "$CHECKSUM_SHA256" \
  '{
    fix_log_entries: $n,
    first_entry_id: (if $first == "null" then null else $first end),
    last_entry_id: (if $last == "null" then null else $last end),
    checksum_sha256: $cs
  }')

# ============================================================
# COMPUTE cdg_decisions (read cdg-tokens.json if exists)
# ============================================================
CDG_TOKENS_FILE="$SESSION_DIR/cdg-tokens.json"
if [ -s "$CDG_TOKENS_FILE" ]; then
  CDG_DECISIONS=$(jq -c '
    if (.tokens // .decisions // []) | type == "array" then
      [(.tokens // .decisions // [])[] | {
        cdg_id: (.cdg_id // null),
        issue_ref: (.issue_id // .issue_ref // null),
        decision: (.decision // .action // null),
        rationale: (.rationale // .reason // null),
        decided_at: (.decided_at // .timestamp // null),
        decided_by: (.decided_by // .user // null)
      }]
    else [] end
  ' "$CDG_TOKENS_FILE" 2>/dev/null || echo '[]')
else
  CDG_DECISIONS='[]'
fi

# ============================================================
# COMPUTE next_recommended_action (logic 3 branches)
# ============================================================
if [ "$ESCALATED" -gt 0 ]; then
  NEXT_SKILL="wf-prepare-deployment"
  NEXT_RATIONALE="$ESCALATED escalated issue(s) cần stakeholder review trước Go-Live — block deployment cho đến khi resolve"
  NEXT_BLOCK_TYPE="escalated"
elif [ "$REGISTRY_CHANGES_COUNT" -gt 0 ]; then
  NEXT_SKILL="wf-verify-sync"
  NEXT_RATIONALE="$REGISTRY_CHANGES_COUNT registry changes — recommend sync verify trước release"
  NEXT_BLOCK_TYPE="none"
else
  NEXT_SKILL="ready-for-release"
  NEXT_RATIONALE="No escalated issues, no registry changes — sẵn sàng release"
  NEXT_BLOCK_TYPE="none"
fi

if [ "$NEXT_BLOCK_TYPE" = "escalated" ]; then
  BLOCKING_ITEMS=$(jq -nc --argjson n "$ESCALATED" \
    '[{type: "escalated", count: $n, note: "Cần stakeholder review trước Go-Live"}]')
else
  BLOCKING_ITEMS='[]'
fi

NEXT_ACTION=$(jq -nc \
  --arg skill "$NEXT_SKILL" \
  --arg rat "$NEXT_RATIONALE" \
  --argjson blocks "$BLOCKING_ITEMS" \
  '{skill: $skill, rationale: $rat, blocking_items: $blocks}')

# ============================================================
# ASSEMBLE final JSON
# ============================================================
GENERATED_AT=$(iso_now)

FINAL_JSON=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg stype "$SCOPE_TYPE" \
  --arg sname "$SCOPE_NAME" \
  --arg ssys "$SCOPE_SYSTEM" \
  --argjson total "$TOTAL_ISSUES" \
  --argjson fix "$FIXED" \
  --argjson def "$DEFERRED" \
  --argjson esc "$ESCALATED" \
  --argjson skp "$SKIPPED" \
  --argjson vit "$VERIFY_ITERATIONS" \
  --argjson by_dim "$BY_DIMENSION_JSON" \
  --argjson code "$CODE_FILES" \
  --argjson feat "$FEATURE_SPECS" \
  --argjson ux "$UX_SPECS" \
  --argjson reg "$REGISTRY_CHANGES" \
  --argjson ev "$VERIFY_EVIDENCE" \
  --argjson reg_check "$REGRESSION_CHECK" \
  --argjson audit "$AUDIT_CHAIN" \
  --argjson cdg "$CDG_DECISIONS" \
  --argjson next "$NEXT_ACTION" \
  --arg gen "$GENERATED_AT" \
  '{
    "$schema": "fix-impact-v1",
    session_id: $sid,
    scope: {type: $stype, name: $sname, system: $ssys},
    fix_summary: {
      total_issues: $total,
      fixed: $fix,
      deferred: $def,
      escalated: $esc,
      skipped: $skp,
      verify_iterations: $vit
    },
    by_dimension: $by_dim,
    affected_artifacts: {
      code_files: $code,
      feature_specs_updated: $feat,
      ux_specs_updated: $ux,
      registry_changes: $reg
    },
    verify_evidence: $ev,
    regression_check: $reg_check,
    audit_chain: $audit,
    cdg_decisions: $cdg,
    next_recommended_action: $next,
    status: "ok",
    generated_at: $gen,
    generator: "wf-fix-bugs v7.4.0"
  }') || {
    echo "ERROR: jq assembly failed" >&2
    write_degraded_stub "jq assembly failed during build" || true
    exit 3
  }

# ============================================================
# WRITE atomic + validate
# ============================================================
atomic_write_json "$OUTPUT" "$FINAL_JSON" || {
  echo "ERROR: atomic_write_json failed" >&2
  write_degraded_stub "atomic_write_json failed" || true
  exit 3
}

# Verify $schema field
SCHEMA=$(jq -r '."$schema"' "$OUTPUT")
[ "$SCHEMA" = "fix-impact-v1" ] || {
  echo "ERROR: schema mismatch in output: $SCHEMA" >&2
  write_degraded_stub "schema mismatch in output: $SCHEMA" || true
  exit 3
}

echo "OK: fix-impact.json generated → $OUTPUT" >&2
echo "    total_issues=$TOTAL_ISSUES fixed=$FIXED escalated=$ESCALATED registry_changes=$REGISTRY_CHANGES_COUNT" >&2
echo "    next_action=$NEXT_SKILL checksum=${CHECKSUM_SHA256:0:16}..." >&2
exit 0
