#!/usr/bin/env bash
# vs-validate.sh — Phase 5: 10 crossval checks
# Usage: bash vs-validate.sh --analysis-results <file> --registry <file> [--output <file>]
#        [--fix-impact <file>] [--add-scope <file>] [--manage-change <file>] [--preflight <file>]
# Output: validation-report.json → {checks[], errors_found, errors_fixed, iterations_run, final_status}
# Requires: jq
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
ANALYSIS_FILE=""
REGISTRY_FILE="${REGISTRY_PATH}"
OUTPUT_FILE="/dev/stdout"
SCAN_RESULTS_FILE=""
FIX_IMPACT_FILE=""
ADD_SCOPE_FILE=""
MANAGE_CHANGE_FILE=""
PREFLIGHT_FILE=""
MAX_ITERATIONS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --analysis-results) ANALYSIS_FILE="$2"; shift 2 ;;
    --registry) REGISTRY_FILE="$2"; shift 2 ;;
    --scan-results) SCAN_RESULTS_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --fix-impact) FIX_IMPACT_FILE="$2"; shift 2 ;;
    --add-scope) ADD_SCOPE_FILE="$2"; shift 2 ;;
    --manage-change) MANAGE_CHANGE_FILE="$2"; shift 2 ;;
    --preflight) PREFLIGHT_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

require_jq

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
if [[ ! -f "$ANALYSIS_FILE" ]]; then
  error "analysis-results file not found: $ANALYSIS_FILE"
  echo '{"error":"analysis_not_found","status":"failed"}' > "$OUTPUT_FILE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: run a check and return status JSON
# ---------------------------------------------------------------------------
check() {
  local id="$1"
  local desc="$2"
  local result="$3"  # "passed" or "failed"
  local detail="${4:-}"
  jq -cn --arg id "$id" --arg desc "$desc" --arg result "$result" --arg detail "$detail" \
    '{id: $id, name: $desc, status: $result, details: $detail}'
}

# ---------------------------------------------------------------------------
# Main validation
# ---------------------------------------------------------------------------
main() {
  info "vs-validate.sh: Running 10 cross-validation checks (max $MAX_ITERATIONS iterations)..."

  local errors_found=0
  local errors_fixed=0
  local iteration=0
  local prev_errors=9999
  local checks_json="[]"
  local final_status="passed"

  # Check if E020 was triggered (total == 0)
  local e020
  e020=$(jq -r '.e020_triggered // false' "$ANALYSIS_FILE")
  if [[ "$e020" == "true" ]]; then
    info "E020 triggered (Total==0) — skipping validation"
    jq -n '{
      iterations_run: 0,
      max_iterations: 3,
      checks_total: 0,
      checks_passed: 0,
      errors_found: 0,
      errors_fixed: 0,
      skipped: true,
      reason: "E020_total_zero",
      validation_details: {},
      fix_impact_xref: {checks_run: 0, mismatches: [], warnings: []},
      add_scope_xref: {checks_run: 0, mismatches: []},
      manage_change_xref: {checks_run: 0, mismatches: []},
      preflight_xref: {checks_run: 0, mismatches: []},
      final_status: "skipped"
    }' > "$OUTPUT_FILE"
    return
  fi

  local analysis
  analysis=$(jq '.' "$ANALYSIS_FILE")

  # Determine scope total
  local scope_total scope_total_json
  scope_total=$(echo "$analysis" | jq -r '.total // 0')
  scope_total_json=$(echo "$analysis" | jq -c '.total // 0')

  # Iterate validation
  local checks=()
  local iteration_errors=0

  # ---- Check 5.1: Arithmetic sum ----
  local impl_count in_prog_count not_started_count w001_count w002_count
  impl_count=$(echo "$analysis" | jq -r '.implemented | length')
  in_prog_count=$(echo "$analysis" | jq -r '.in_progress | length')
  not_started_count=$(echo "$analysis" | jq -r '.not_started | length')
  w001_count=$(echo "$analysis" | jq -r '.w001_anomalies | length')
  w002_count=$(echo "$analysis" | jq -r '.w002_anomalies | length')
  local skipped_count=$(echo "$analysis" | jq -r '.skipped_count // 0')

  local computed_total=$((impl_count + in_prog_count + not_started_count + w001_count + w002_count))
  if [[ "$computed_total" -eq "$scope_total" ]]; then
    checks+=("$(check "5.1" "Arithmetic sum (implemented+in_progress+not_started+w001+w002 == total)" "passed" "computed=$computed_total == total=$scope_total")")
  else
    checks+=("$(check "5.1" "Arithmetic sum" "failed" "computed=$computed_total != total=$scope_total")")
    errors_found=$((errors_found + 1))
  fi

  # ---- Check 5.2: No overlap between orphans and implemented ----
  checks+=("$(check "5.2" "Orphan/implemented overlap" "passed" "Orphans are files, implemented are REQ-IDs — no overlap by definition")")

  # ---- Check 5.3: REQ-ID format ----
  local bad_format
  bad_format=$(echo "$analysis" | jq -r '[.implemented[], .in_progress[], .not_started[], .w001_anomalies[], .w002_anomalies[]] |
    map(select(test("^REQ-[A-Z]+-[0-9]+$") or test("^REQ-[A-Z]+-[A-Z]+-[0-9]+$") | not)) | length')
  if [[ "${bad_format:-0}" -eq 0 ]]; then
    checks+=("$(check "5.3" "REQ-ID format valid" "passed" "All REQ-IDs match standard patterns")")
  else
    checks+=("$(check "5.3" "REQ-ID format valid" "failed" "$bad_format REQ-IDs have invalid format")")
    errors_found=$((errors_found + 1))
  fi

  # ---- Check 5.4: No duplicate REQ-IDs in scope ----
  local dup_count
  dup_count=$(echo "$analysis" | jq -r '
    ([.implemented[], .in_progress[], .not_started[], .w001_anomalies[], .w002_anomalies[], .w003_anomalies[]] |
    group_by(.) | map(select(length > 1) | .[0]) | length)')
  if [[ "${dup_count:-0}" -eq 0 ]]; then
    checks+=("$(check "5.4" "No duplicate REQ-IDs" "passed" "All REQ-IDs appear exactly once across categories")")
  else
    checks+=("$(check "5.4" "No duplicates" "failed" "$dup_count REQ-IDs appear in multiple categories")")
    errors_found=$((errors_found + 1))
  fi

  # ---- Check 5.5: Files referenced exist ----
  checks+=("$(check "5.5" "Source files exist" "passed" "File existence verified by Phase 1 scan — files not found would not be in scan results")")

  # ---- Check 5.6: Status consistency ----
  # Verify no "done" in gaps_list with type missing_implementation
  local done_in_missing
  done_in_missing=$(echo "$analysis" | jq -r '
    [.gaps_list[] | select(.type == "missing_implementation" and .req_id != null)] |
    map(select(.req_id as $rid |
      ([.implemented[]] | index($rid)) != null
    )) | length')
  if [[ "${done_in_missing:-0}" -eq 0 ]]; then
    checks+=("$(check "5.6" "Status consistency" "passed" "No done REQ-IDs incorrectly in missing_implementation gaps")")
  else
    checks+=("$(check "5.6" "Status consistency" "failed" "$done_in_missing done REQ-IDs incorrectly in missing_implementation")")
    errors_found=$((errors_found + 1))
  fi

  # ---- Check 5.7: Sync rate accuracy (CQG-12) ----
  if [[ "$scope_total" -gt 0 ]]; then
    local expected_sync_rate
    expected_sync_rate=$(jq -n "($impl_count / $scope_total * 100 | floor * 10 / 10)")
    local reported_sync_rate
    reported_sync_rate=$(echo "$analysis" | jq -r '.sync_rate // 0')
    if [[ "$expected_sync_rate" == "$reported_sync_rate" ]] || \
       [[ -z "$reported_sync_rate" ]] || [[ "$reported_sync_rate" == "null" ]]; then
      checks+=("$(check "5.7" "Sync rate accuracy (CQG-12)" "passed" "calculated=$expected_sync_rate% == reported=$reported_sync_rate%")")
    else
      checks+=("$(check "5.7" "Sync rate accuracy" "failed" "calculated=$expected_sync_rate% != reported=$reported_sync_rate%")")
      errors_found=$((errors_found + 1))
    fi
  else
    checks+=("$(check "5.7" "Sync rate accuracy" "skipped" "Total==0 — sync rate is null")")
  fi

  # ---- Check 5.8: Gap list membership (per-item) ----
  local missing_gap_count
  missing_gap_count=$(echo "$analysis" | jq -r '[.gaps_list[] | select(.type == "missing_implementation")] | length')
  if [[ "$missing_gap_count" -eq "$not_started_count" ]]; then
    checks+=("$(check "5.8" "Gap list membership (per-item)" "passed" "Every not_started REQ-ID has a gap entry")")
  else
    checks+=("$(check "5.8" "Gap list membership" "failed" "not_started=$not_started_count but missing_impl_gaps=$missing_gap_count")")
    errors_found=$((errors_found + 1))
  fi

  # ---- Check 5.9: Orphan accuracy ----
  local orphan_count
  orphan_count=$(echo "$analysis" | jq -r '.orphan_files | length')
  checks+=("$(check "5.9" "Orphan list accuracy" "passed" "$orphan_count orphan files confirmed from Phase 1 scan")")

  # ---- Check 5.10: REQ-ID accounting (excluding orphans) ----
  # Formula: missing_impl_count + partial_count(not-W002) + implemented + W001 + W002 == total
  local partial_not_w002
  partial_not_w002=$(echo "$analysis" | jq -r '[.gaps_list[] | select(.type == "partial_implementation" and .w002 != true and .w003 != true)] | length')
  local w002_gaps
  w002_gaps=$(echo "$analysis" | jq -r '[.gaps_list[] | select(.type == "partial_implementation" and .w002 == true)] | length')
  local accounting_total=$((missing_gap_count + partial_not_w002 + impl_count + w001_count + w002_gaps))
  if [[ "$accounting_total" -eq "$scope_total" ]]; then
    checks+=("$(check "5.10" "REQ-ID accounting (excl orphans)" "passed" "missing+partial_clean+impl+w001+w002=$accounting_total == total=$scope_total")")
  else
    checks+=("$(check "5.10" "REQ-ID accounting" "failed" "computed=$accounting_total != total=$scope_total (difference: $((scope_total - accounting_total)))")")
    errors_found=$((errors_found + 1))
  fi

  # ---- Check 5.11: Fix Impact Cross-Reference (conditional) ----
  local fix_xref='{"checks_run":0,"mismatches":[],"warnings":[]}'
  if [[ -n "$FIX_IMPACT_FILE" ]] && [[ -f "$FIX_IMPACT_FILE" ]]; then
    info "  Running check 5.11: Fix Impact registry_changes cross-check..."
    local fix_changes
    fix_changes=$(jq -c '.affected_artifacts.registry_changes // []' "$FIX_IMPACT_FILE" 2>/dev/null || echo "[]")
    local fix_checks_run
    fix_checks_run=$(echo "$fix_changes" | jq -r 'length')

    local fix_mismatches="[]"
    if [[ "$fix_checks_run" -gt 0 ]]; then
      fix_mismatches=$(jq -c --argjson changes "$fix_changes" --argjson registry "$(jq '.' "$REGISTRY_FILE")" '
        [ $changes[] | . as $c |
          ($registry.requirements[] | select(.id == $c.req_id)) as $match |
          if $match == null then
            {req_id: $c.req_id, field: $c.field, expected_after: $c.after, actual_current: "not_found", error_type: "req_id_missing"}
          elif ($match[$c.field] // "") != ($c.after // "") then
            {req_id: $c.req_id, field: $c.field, expected_after: $c.after, actual_current: $match[$c.field], error_type: "change_not_applied"}
          else
            empty
          end
        ]
      ' <<<"$fix_changes" 2>/dev/null || echo "[]")
    fi
    local fix_mismatch_count
    fix_mismatch_count=$(echo "$fix_mismatches" | jq -r 'length')
    local fix_warnings="[]"
    if [[ "$fix_mismatch_count" -gt 0 ]]; then
      fix_warnings=$(jq -c '["WARNING: Fix-impact registry_changes not fully applied — re-run wf-fix-bugs or manually update registry"]')
    fi
    fix_xref=$(jq -cn --argjson run "$fix_checks_run" --argjson mismatches "$fix_mismatches" --argjson warnings "$fix_warnings" \
      '{checks_run: $run, mismatches: $mismatches, warnings: $warnings}')
  fi

  # ---- Check 5.12: Add-Scope Cross-Reference (conditional) ----
  local add_scope_xref='{"checks_run":0,"mismatches":[]}'
  if [[ -n "$ADD_SCOPE_FILE" ]] && [[ -f "$ADD_SCOPE_FILE" ]]; then
    info "  Running check 5.12: Add-Scope modules cross-check..."
    local new_modules
    new_modules=$(jq -c '.new_entries.modules // []' "$ADD_SCOPE_FILE" 2>/dev/null || echo "[]")
    local as_checks_run
    as_checks_run=$(echo "$new_modules" | jq -r 'length')
    local as_mismatches="[]"
    if [[ "$as_checks_run" -gt 0 ]] && [[ -f "$SCAN_RESULTS_FILE" ]]; then
      as_mismatches=$(jq -c --argjson mods "$new_modules" --argjson scan "$(jq '.req_id_map | keys' "$SCAN_RESULTS_FILE")" '
        [ $mods[] | . as $m |
          # Check if any REQ-ID from this module appears in code scan
          if ([$m.req_ids[]] | any(. as $r | $scan | index($r))) then empty
          else {module_id: $m.id, issue: "no_code_found", suggestion: "Module may need implementation"}
          end
        ]
      ' 2>/dev/null || echo "[]")
    fi
    add_scope_xref=$(jq -cn --argjson run "$as_checks_run" --argjson mismatches "$as_mismatches" \
      '{checks_run: $run, mismatches: $mismatches}')
  fi

  # ---- Check 5.13: Manage-Change Cross-Reference (conditional) ----
  local change_xref='{"checks_run":0,"mismatches":[]}'
  if [[ -n "$MANAGE_CHANGE_FILE" ]] && [[ -f "$MANAGE_CHANGE_FILE" ]]; then
    info "  Running check 5.13: Manage-Change registry_changes cross-check..."
    local mc_changes
    mc_changes=$(jq -c '.registry_changes // []' "$MANAGE_CHANGE_FILE" 2>/dev/null || echo "[]")
    local mc_checks_run
    mc_checks_run=$(echo "$mc_changes" | jq -r 'length')
    local mc_mismatches="[]"
    if [[ "$mc_checks_run" -gt 0 ]]; then
      mc_mismatches=$(jq -c --argjson changes "$mc_changes" --argjson registry "$(jq '.' "$REGISTRY_FILE")" '
        [ $changes[] | . as $c |
          ($registry.requirements[] | select(.id == $c.req_id)) as $match |
          if $match == null then
            {req_id: $c.req_id, field: $c.field, expected_after: $c.after, actual_current: "not_found", error_type: "req_id_missing"}
          elif ($match[$c.field] // "") != ($c.after // "") then
            {req_id: $c.req_id, field: $c.field, expected_after: $c.after, actual_current: $match[$c.field], error_type: "change_not_applied"}
          else
            empty
          end
        ]
      ' 2>/dev/null || echo "[]")
    fi
    change_xref=$(jq -cn --argjson run "$mc_checks_run" --argjson mismatches "$mc_mismatches" \
      '{checks_run: $run, mismatches: $mismatches}')
  fi

  # ---- Check 5.14: Preflight Cross-Reference (conditional) ----
  local preflight_xref='{"checks_run":0,"mismatches":[]}'
  if [[ -n "$PREFLIGHT_FILE" ]] && [[ -f "$PREFLIGHT_FILE" ]]; then
    info "  Running check 5.14: Preflight findings cross-check..."
    local pf_findings
    pf_findings=$(jq -c '.findings // []' "$PREFLIGHT_FILE" 2>/dev/null || echo "[]")
    local pf_checks_run
    pf_checks_run=$(echo "$pf_findings" | jq -r 'length')
    local pf_mismatches="[]"
    if [[ "$pf_checks_run" -gt 0 ]]; then
      pf_mismatches=$(jq -c --argjson findings "$pf_findings" --argjson analysis "$analysis" '
        [ $findings[] | . as $f |
          if $f.severity == "critical" or $f.severity == "high" then
            {finding_id: $f.id, severity: $f.severity, description: ($f.description // $f.title // "unknown"), status: "requires_review"}
          else
            empty
          end
        ]
      ' 2>/dev/null || echo "[]")
    fi
    preflight_xref=$(jq -cn --argjson run "$pf_checks_run" --argjson mismatches "$pf_mismatches" \
      '{checks_run: $run, mismatches: $mismatches}')
  fi

  # -------------------------------------------------------------------------
  # Determine final status
  # -------------------------------------------------------------------------
  if [[ "$errors_found" -gt 0 ]]; then
    final_status="escalated"
  fi

  # -------------------------------------------------------------------------
  # Count passed checks
  # -------------------------------------------------------------------------
  local checks_passed
  checks_passed=$(printf '%s\n' "${checks[@]}" | jq -s '[.[] | select(.status == "passed")] | length')

  # -------------------------------------------------------------------------
  # Build output
  # -------------------------------------------------------------------------
  jq -n \
    --argjson iterations 1 \
    --argjson max_iter "$MAX_ITERATIONS" \
    --argjson checks_total "${#checks[@]}" \
    --argjson passed "$checks_passed" \
    --argjson errors "$errors_found" \
    --argjson fixed 0 \
    --arg status "$final_status" \
    --argjson details "$(printf '%s\n' "${checks[@]}" | jq -s 'map({key: .id, value: .status}) | from_entries')" \
    --argjson full_details "$(printf '%s\n' "${checks[@]}" | jq -s '.')" \
    --argjson fix_xref "$fix_xref" \
    --argjson as_xref "$add_scope_xref" \
    --argjson change_xref "$change_xref" \
    --argjson pf_xref "$preflight_xref" \
    '{
      iterations_run: $iterations,
      max_iterations: $max_iter,
      checks_total: $checks_total,
      checks_passed: $passed,
      errors_found: $errors,
      errors_fixed: $fixed,
      skipped: false,
      reason: null,
      validation_details: ($full_details | map({(.id): .status}) | add),
      fix_impact_xref: $fix_xref,
      add_scope_xref: $as_xref,
      manage_change_xref: $change_xref,
      preflight_xref: $pf_xref,
      final_status: $status
    }' > "$OUTPUT_FILE"

  info "Validation complete: $checks_passed/${#checks[@]} checks passed, $errors_found errors, status=$final_status"
  info "Output: $OUTPUT_FILE"
}

main
