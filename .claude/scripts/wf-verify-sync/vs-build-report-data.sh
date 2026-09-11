#!/usr/bin/env bash
# vs-build-report-data.sh — Phase 6: aggregate all phase outputs → report-data.json
# Usage: bash vs-build-report-data.sh --analysis-results <file> [--ui-scan <file>]
#        [--validation <file>] [--registry <file>] [--fix-log <file>] [--output <file>]
#        [--fix-impact <file>] [--add-scope <file>] [--manage-change <file>] [--preflight <file>]
# Output: report-data.json — all fields pre-computed for markdown rendering
# Requires: jq
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
ANALYSIS_FILE=""
UI_SCAN_FILE=""
VALIDATION_FILE=""
REGISTRY_FILE="${REGISTRY_PATH}"
FIX_LOG_FILE=""
OUTPUT_FILE="/dev/stdout"
FIX_IMPACT_FILE=""
ADD_SCOPE_FILE=""
MANAGE_CHANGE_FILE=""
PREFLIGHT_FILE=""
SESSION_ID="${SESSION_ID:-unknown}"
SCOPE_TYPE="${SCOPE_TYPE:-all}"
SCOPE_NAME="${SCOPE_NAME:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --analysis-results) ANALYSIS_FILE="$2"; shift 2 ;;
    --ui-scan) UI_SCAN_FILE="$2"; shift 2 ;;
    --validation) VALIDATION_FILE="$2"; shift 2 ;;
    --registry) REGISTRY_FILE="$2"; shift 2 ;;
    --fix-log) FIX_LOG_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --fix-impact) FIX_IMPACT_FILE="$2"; shift 2 ;;
    --add-scope) ADD_SCOPE_FILE="$2"; shift 2 ;;
    --manage-change) MANAGE_CHANGE_FILE="$2"; shift 2 ;;
    --preflight) PREFLIGHT_FILE="$2"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --scope) SCOPE_TYPE="$2"; shift 2 ;;
    --scope-name) SCOPE_NAME="$2"; shift 2 ;;
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
# Main: aggregate all data sources
# ---------------------------------------------------------------------------
main() {
  info "vs-build-report-data.sh: Aggregating phase outputs..."

  local analysis
  analysis=$(jq '.' "$ANALYSIS_FILE")

  # -------------------------------------------------------------------------
  # Read analysis data
  # -------------------------------------------------------------------------
  local total impl_count in_prog_count not_started skipped_count
  local w001_count w002_count w003_count orphan_count sync_rate coverage_rate
  local e020 feature_summary fiprogress_count fiprogress_list
  local w001_arr w002_arr w003_arr gaps_list

  total=$(echo "$analysis" | jq -r '.total // 0')
  impl_count=$(echo "$analysis" | jq -r '.implemented | length')
  in_prog_count=$(echo "$analysis" | jq -r '.in_progress | length')
  not_started=$(echo "$analysis" | jq -r '.not_started | length')
  skipped_count=$(echo "$analysis" | jq -r '.skipped_count // 0')
  w001_count=$(echo "$analysis" | jq -r '.w001_anomalies | length')
  w002_count=$(echo "$analysis" | jq -r '.w002_anomalies | length')
  w003_count=$(echo "$analysis" | jq -r '.w003_anomalies | length')
  orphan_count=$(echo "$analysis" | jq -r '.orphan_files | length')
  sync_rate=$(echo "$analysis" | jq -r '.sync_rate // "null"')
  coverage_rate=$(echo "$analysis" | jq -r '.coverage_rate // "null"')
  e020=$(echo "$analysis" | jq -r '.e020_triggered // false')
  feature_summary=$(echo "$analysis" | jq -c '.feature_summary // {}')
  fiprogress_count=$(echo "$feature_summary" | jq -r '.in_progress // 0')
  fiprogress_list=$(echo "$analysis" | jq -c '.in_progress_features_list // []')
  w001_arr=$(echo "$analysis" | jq -c '.w001_anomalies // []')
  w002_arr=$(echo "$analysis" | jq -c '.w002_anomalies // []')
  w003_arr=$(echo "$analysis" | jq -c '.w003_anomalies // []')
  gaps_list=$(echo "$analysis" | jq -c '.gaps_list // []')

  # -------------------------------------------------------------------------
  # Compute verdict (v3.3+ logic with priority override)
  # -------------------------------------------------------------------------
  local verdict critical_high_not_started
  critical_high_not_started=$(jq -r '[.requirements[] | select(.impl_status=="not_started" and (.priority=="critical" or .priority=="high"))] | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)

  verdict=$(jq -n \
    --argjson rate "$sync_rate" \
    --argjson ns "$not_started" \
    --argjson fiprogress "$fiprogress_count" \
    --argjson crithigh_ns "$critical_high_not_started" \
    'if ($crithigh_ns > 0) then "NOT_READY"
     elif ($rate >= 80) and ($ns == 0) and ($fiprogress == 0) then "READY"
     elif ($rate >= 80) and ($fiprogress > 0) then "PARTIAL_FEATURES"
     elif ($rate >= 60) then "PARTIAL"
     else "NOT_READY"
     end')
  verdict="${verdict//\"/}"

  # -------------------------------------------------------------------------
  # UI coverage data (optional)
  # -------------------------------------------------------------------------
  local ui_data="null"
  if [[ -n "$UI_SCAN_FILE" ]] && [[ -f "$UI_SCAN_FILE" ]]; then
    ui_data=$(jq -c '{
      ran: true,
      total_screens: .total_screens,
      total_business_screens: .total_business_screens,
      infrastructure_count: .infrastructure_count,
      matched_count: .matches.matched_count,
      partial_match_count: .matches.partial_match_count,
      missing_from_features_count: .matches.missing_from_features_count,
      missing_from_code_count: .matches.missing_from_code_count,
      coverage_pct: .coverage_pct,
      partial_coverage_pct: .partial_coverage_pct,
      missing_from_features: .matches.missing_from_features,
      missing_from_code: .matches.missing_from_code,
      skipped: .skipped
    }' "$UI_SCAN_FILE" 2>/dev/null || echo "null")
  fi

  # -------------------------------------------------------------------------
  # Validation data (optional)
  # -------------------------------------------------------------------------
  local validation_data="null"
  if [[ -n "$VALIDATION_FILE" ]] && [[ -f "$VALIDATION_FILE" ]]; then
    validation_data=$(jq -c '{
      iterations_run: .iterations_run,
      checks_passed: .checks_passed,
      checks_total: .checks_total,
      errors_found: .errors_found,
      errors_fixed: .errors_fixed,
      final_status: .final_status,
      skipped: .skipped,
      details: .validation_details
    }' "$VALIDATION_FILE" 2>/dev/null || echo "null")
  fi

  # -------------------------------------------------------------------------
  # Fix log (optional)
  # -------------------------------------------------------------------------
  local fix_data="null"
  if [[ -n "$FIX_LOG_FILE" ]] && [[ -f "$FIX_LOG_FILE" ]]; then
    fix_data=$(jq -c '{applied: true, entries: .}' "$FIX_LOG_FILE" 2>/dev/null || echo '{"applied":false,"entries":[]}')
  fi

  # -------------------------------------------------------------------------
  # Fix impact context (optional)
  # -------------------------------------------------------------------------
  local fix_impact_data="null"
  if [[ -n "$FIX_IMPACT_FILE" ]] && [[ -f "$FIX_IMPACT_FILE" ]]; then
    fix_impact_data=$(jq -c '{
      source_session: (.session_id // "unknown"),
      generated_at: (.generated_at // "unknown"),
      audit_checksum: (.audit_chain.checksum_sha256 // "unknown"),
      total: (.verify_summary.total // 0),
      fixed: (.verify_summary.fixed // 0),
      deferred: (.verify_summary.deferred // 0),
      escalated: (.verify_summary.escalated // 0),
      skipped_fixes: (.verify_summary.skipped // 0),
      next_skill: (.next_recommended_action.skill // null),
      next_rationale: (.next_recommended_action.rationale // null),
      blocking_items: (.next_recommended_action.blocking_items // [])
    }' "$FIX_IMPACT_FILE" 2>/dev/null || echo "null")
  fi

  # -------------------------------------------------------------------------
  # Add-scope context (optional)
  # -------------------------------------------------------------------------
  local add_scope_data="null"
  if [[ -n "$ADD_SCOPE_FILE" ]] && [[ -f "$ADD_SCOPE_FILE" ]]; then
    add_scope_data=$(jq -c '{
      session_id: (.session_id // "unknown"),
      new_modules: (.new_entries.modules // []),
      new_features: (.new_entries.features // []),
      summary: (.summary // {})
    }' "$ADD_SCOPE_FILE" 2>/dev/null || echo "null")
  fi

  # -------------------------------------------------------------------------
  # Manage-change context (optional)
  # -------------------------------------------------------------------------
  local change_data="null"
  if [[ -n "$MANAGE_CHANGE_FILE" ]] && [[ -f "$MANAGE_CHANGE_FILE" ]]; then
    change_data=$(jq -c '{
      change_id: (.change_id // "unknown"),
      registry_changes: (.registry_changes // []),
      files_modified: (.files_modified // []),
      summary: (.summary // {})
    }' "$MANAGE_CHANGE_FILE" 2>/dev/null || echo "null")
  fi

  # -------------------------------------------------------------------------
  # Preflight context (optional)
  # -------------------------------------------------------------------------
  local preflight_data="null"
  if [[ -n "$PREFLIGHT_FILE" ]] && [[ -f "$PREFLIGHT_FILE" ]]; then
    preflight_data=$(jq -c '{
      session_id: (.session_id // "unknown"),
      verdict: (.verdict // "unknown"),
      score: (.score // 0),
      critical_count: (.critical_count // 0),
      high_count: (.high_count // 0),
      scope: (.scope // {}),
      findings: (.findings // [])
    }' "$PREFLIGHT_FILE" 2>/dev/null || echo "null")
  fi

  # -------------------------------------------------------------------------
  # Next recommended action
  # -------------------------------------------------------------------------
  local next_skill next_rationale
  case "$verdict" in
    READY)
      next_skill="wf-prepare-deployment"
      next_rationale="Sync rate ${sync_rate}% READY và không còn not_started. Khuyến nghị chạy /wf-prepare-deployment."
      ;;
    PARTIAL_FEATURES)
      next_skill="wf-implement-feature"
      next_rationale="Sync rate ${sync_rate}% PARTIAL_FEATURES — ${fiprogress_count} features còn in_progress. Hoàn thành features trước khi chạy /wf-prepare-deployment."
      ;;
    PARTIAL)
      next_skill="wf-implement-feature"
      next_rationale="Sync rate ${sync_rate}% PARTIAL — ${not_started} REQ-IDs chưa implement."
      ;;
    NOT_READY)
      next_skill="wf-implement-feature"
      next_rationale="Sync rate ${sync_rate}% NOT_READY — ${not_started} REQ-IDs chưa implement."
      ;;
  esac

  # -------------------------------------------------------------------------
  # Build final report-data.json
  # -------------------------------------------------------------------------
  jq -n \
    --arg sid "$SESSION_ID" \
    --arg scope_type "$SCOPE_TYPE" \
    --arg scope_name "$SCOPE_NAME" \
    --arg ts "$(get_timestamp)" \
    --argjson total "$total" \
    --argjson implemented "$impl_count" \
    --argjson in_progress "$in_prog_count" \
    --argjson not_started "$not_started" \
    --argjson skipped "$skipped_count" \
    --argjson orphan "$orphan_count" \
    --argjson sync_rate "$sync_rate" \
    --argjson coverage_rate "$coverage_rate" \
    --arg verdict "$verdict" \
    --argjson w001_count "$w001_count" \
    --argjson w001_arr "$w001_arr" \
    --argjson w002_count "$w002_count" \
    --argjson w002_arr "$w002_arr" \
    --argjson w003_count "$w003_count" \
    --argjson w003_arr "$w003_arr" \
    --argjson e020 "$e020" \
    --argjson feature_summary "$feature_summary" \
    --argjson fiprogress "$fiprogress_count" \
    --argjson fiprogress_list "$fiprogress_list" \
    --argjson crithigh_ns "$critical_high_not_started" \
    --argjson gaps "$gaps_list" \
    --argjson ui "$ui_data" \
    --argjson validation "$validation_data" \
    --argjson fix "$fix_data" \
    --argjson fix_impact "$fix_impact_data" \
    --argjson add_scope "$add_scope_data" \
    --argjson manage_change "$change_data" \
    --argjson preflight "$preflight_data" \
    --arg next_skill "/${next_skill}" \
    --arg next_rationale "$next_rationale" \
    '{
      report_metadata: {
        session_id: $sid,
        scope: {type: $scope_type, name: $scope_name},
        generated_at: $ts,
        e020_triggered: $e020
      },
      summary: {
        total_req_ids: $total,
        implemented: $implemented,
        in_progress: $in_progress,
        not_started: $not_started,
        skipped: $skipped,
        orphan_files: $orphan,
        sync_rate_pct: $sync_rate,
        coverage_rate_pct: $coverage_rate,
        verdict: $verdict,
        critical_high_not_started: $crithigh_ns
      },
      warnings: {
        w001_count: $w001_count,
        w001_anomalies: $w001_arr,
        w002_count: $w002_count,
        w002_anomalies: $w002_arr,
        w003_count: $w003_count,
        w003_anomalies: $w003_arr
      },
      feature_completion: $feature_summary,
      has_in_progress_features: ($fiprogress > 0),
      in_progress_features_list: $fiprogress_list,
      gaps_list: $gaps,
      ui_coverage: $ui,
      validation: $validation,
      fix_log: $fix,
      cross_references: {
        fix_impact: $fix_impact,
        add_scope: $add_scope,
        manage_change: $manage_change,
        preflight: $preflight
      },
      next_recommended_action: {
        skill: $next_skill,
        rationale: $next_rationale
      }
    }' > "$OUTPUT_FILE"

  info "Report data built: verdict=$verdict, sync_rate=$sync_rate%, w001=$w001_count, w003=$w003_count"
  info "Output: $OUTPUT_FILE"
}

main
