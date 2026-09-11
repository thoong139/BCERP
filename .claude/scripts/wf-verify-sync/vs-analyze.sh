#!/usr/bin/env bash
# vs-analyze.sh — Phase 2: match REQ_INDEX vs CODE_REFS
# Usage: bash vs-analyze.sh --scan-results <file> --registry <file> [--output <file>]
# Output: analysis-results.json → {implemented[], in_progress[], w001[], w002[], w003[],
#         not_started[], skipped[], orphan[], sync_rate, coverage_rate, feature_summary,
#         gaps_list[]}
# Requires: jq
set -euo pipefail
export MSYS_NO_PATHCONV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vs-common.sh"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
SCAN_RESULTS_FILE=""
REGISTRY_FILE="${REGISTRY_PATH}"
OUTPUT_FILE="/dev/stdout"
SCOPE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan-results) SCAN_RESULTS_FILE="$2"; shift 2 ;;
    --registry) REGISTRY_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --scope-file) SCOPE_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

require_jq

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
if [[ ! -f "$SCAN_RESULTS_FILE" ]]; then
  error "scan-results file not found: $SCAN_RESULTS_FILE"
  echo '{"error":"scan_results_not_found","status":"failed"}' > "$OUTPUT_FILE"
  exit 1
fi
if [[ ! -f "$REGISTRY_FILE" ]]; then
  error "registry file not found: $REGISTRY_FILE"
  echo '{"error":"registry_not_found","status":"failed"}' > "$OUTPUT_FILE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Main analysis
# ---------------------------------------------------------------------------
main() {
  info "vs-analyze.sh: Matching REQ_INDEX vs CODE_REFS..."

  # Extract data from scan results
  local scan_data
  scan_data=$(jq '.' "$SCAN_RESULTS_FILE")

  # Get set of REQ-IDs found in code scan
  local code_req_ids
  code_req_ids=$(echo "$scan_data" | jq -r '.req_id_map | keys | .[]' 2>/dev/null || echo "")

  # Build a JSON array of code-found REQ-IDs for quick lookup
  local code_req_ids_json
  code_req_ids_json=$(echo "$scan_data" | jq -c '[.req_id_map | keys | .[]]' 2>/dev/null || echo "[]")

  # Get orphan files
  local orphans_json
  orphans_json=$(echo "$scan_data" | jq -c '.orphan_files // []')

  # -------------------------------------------------------------------------
  # Feature status cross-check: build set of REQ-IDs belonging to incomplete features
  # -------------------------------------------------------------------------
  local incomplete_feature_reqs_json
  incomplete_feature_reqs_json=$(jq -c '
    [
      (.features // [])[] |
      select(.impl_status != "done" and .impl_status != "skipped") |
      (.req_ids // [])[]
    ] | unique
  ' "$REGISTRY_FILE" 2>/dev/null || echo "[]")

  # -------------------------------------------------------------------------
  # Feature summary (global, not scope-filtered)
  # -------------------------------------------------------------------------
  local feature_summary
  feature_summary=$(jq -c '{
    total: ((.features // []) | length),
    done: [.features[] | select(.impl_status == "done")] | length,
    in_progress: [.features[] | select(.impl_status == "in_progress")] | length,
    not_started: [.features[] | select(.impl_status == "not_started")] | length,
    skipped: [.features[] | select(.impl_status == "skipped")] | length
  }' "$REGISTRY_FILE" 2>/dev/null || echo '{"total":0,"done":0,"in_progress":0,"not_started":0,"skipped":0}')

  local features_in_progress
  features_in_progress=$(echo "$feature_summary" | jq -r '.in_progress // 0')
  local has_in_progress_features="false"
  if [[ "$features_in_progress" -gt 0 ]]; then
    has_in_progress_features="true"
  fi

  local in_progress_features_list
  in_progress_features_list=$(jq -c '
    [
      (.features // [])[] |
      select(.impl_status == "in_progress") |
      {id: .id, name: .name}
    ] | sort_by(.id) | .[0:20]
  ' "$REGISTRY_FILE" 2>/dev/null || echo "[]")

  # -------------------------------------------------------------------------
  # Scope filter: build REQ-ID set from scope file or use all
  # -------------------------------------------------------------------------
  local scope_req_ids_json="[]"
  if [[ -n "$SCOPE_FILE" ]] && [[ -f "$SCOPE_FILE" ]]; then
    scope_req_ids_json=$(jq -c '.req_ids // []' "$SCOPE_FILE" 2>/dev/null || echo "[]")
  fi

  # If no scope, get all REQ-IDs from registry
  if [[ "$scope_req_ids_json" == "[]" ]]; then
    scope_req_ids_json=$(jq -c '[.requirements[].id] | unique' "$REGISTRY_FILE")
  fi

  # -------------------------------------------------------------------------
  # Main categorization logic using jq
  # -------------------------------------------------------------------------
  jq -n \
    --argjson registry "$(jq '.' "$REGISTRY_FILE")" \
    --argjson code_req_ids "$code_req_ids_json" \
    --argjson orphans "$orphans_json" \
    --argjson incomplete_reqs "$incomplete_feature_reqs_json" \
    --argjson scope_req_ids "$scope_req_ids_json" \
    --argjson feature_sum "$feature_summary" \
    --argjson has_fiprogress "$has_in_progress_features" \
    --argjson fiprogress_list "$in_progress_features_list" \
  '
    # Helper: is a REQ-ID in code?
    def in_code($id): ($code_req_ids | index($id)) != null;
    # Helper: is a REQ-ID in an incomplete feature?
    def in_incomplete_feature($id): ($incomplete_reqs | index($id)) != null;

    # Filter requirements to scope
    (if ($scope_req_ids | length) > 0 then
      [$registry.requirements[] | select(.id as $id | $scope_req_ids | index($id))]
    else
      $registry.requirements
    end) as $scope_reqs |

    # Skip count
    ([$scope_reqs[] | select(.impl_status == "skipped")] | length) as $skipped_count |

    # Total (excluding skipped)
    ([$scope_reqs[] | select(.impl_status != "skipped")] | length) as $total |

    # W001: impl_status=done but NOT in code
    ([$scope_reqs[] | select(.impl_status == "done" and (in_code(.id) | not))] | [.[].id]) as $w001 |

    # W002: impl_status=in_progress but NOT in code
    ([$scope_reqs[] | select(.impl_status == "in_progress" and (in_code(.id) | not))] | [.[].id]) as $w002 |

    # W003: impl_status=done AND in code BUT feature not done
    ([$scope_reqs[] | select(.impl_status == "done" and in_code(.id) and in_incomplete_feature(.id))] | [.[].id]) as $w003 |

    # Implemented: done + in code + NOT W003
    ([$scope_reqs[] | select(
      .impl_status == "done" and in_code(.id) and (in_incomplete_feature(.id) | not)
    )] | [.[].id]) as $implemented |

    # In Progress (with code): in_progress + in code, PLUS W003
    ([$scope_reqs[] | select(
      (.impl_status == "in_progress" and in_code(.id)) or
      (.impl_status == "done" and in_code(.id) and in_incomplete_feature(.id))
    )] | [.[].id]) as $in_progress_with_code |

    # Not Started: not_started + NOT in code
    ([$scope_reqs[] | select(.impl_status == "not_started" and (in_code(.id) | not))] | [.[].id]) as $not_started |

    # Not Started WITH code: not_started but code exists (unusual)
    ([$scope_reqs[] | select(.impl_status == "not_started" and in_code(.id))] | [.[].id]) as $not_started_with_code |

    # Not Started (all): all not_started
    ([$scope_reqs[] | select(.impl_status == "not_started")] | [.[].id]) as $all_not_started |

    # Skipped
    ([$scope_reqs[] | select(.impl_status == "skipped")] | [.[].id]) as $skipped |

    # Compute rates
    ($implemented | length) as $impl_count |
    ($in_progress_with_code | length) as $in_progress_count |
    ($all_not_started | length) as $not_started_count |

    (if $total > 0 then
      ($impl_count / $total * 100 | floor * 10 / 10)
    else null end) as $sync_rate |

    (if $total > 0 then
      (($impl_count + $in_progress_count) / $total * 100 | floor * 10 / 10)
    else null end) as $coverage_rate |

    # Build gaps list
    {
      "implemented": $implemented,
      "in_progress": $in_progress_with_code,
      "not_started": $all_not_started,
      "skipped": $skipped,
      "w001_anomalies": $w001,
      "w002_anomalies": $w002,
      "w003_anomalies": $w003,
      "orphan_files": $orphans,
      "not_started_with_code": $not_started_with_code,
      "sync_rate": $sync_rate,
      "coverage_rate": $coverage_rate,
      "total": $total,
      "skipped_count": $skipped_count,
      "e020_triggered": ($total == 0),
      "feature_summary": $feature_sum,
      "has_in_progress_features": $has_fiprogress,
      "in_progress_features_list": $fiprogress_list,
      "gaps_list": (
        # Missing implementations
        ([$scope_reqs[] | select(.impl_status == "not_started" and (in_code(.id) | not)) |
          {req_id: .id, type: "missing_implementation", priority: .priority, suggested_action: ("Implement " + .id)}]
        ) +
        # Partial implementations (W002: in_progress but no code)
        ([$scope_reqs[] | select(.impl_status == "in_progress" and (in_code(.id) | not)) |
          {req_id: .id, type: "partial_implementation", priority: .priority, suggested_action: ("Complete implementation for " + .id), w002: true}]
        ) +
        # Partial implementations (W003: done but feature incomplete)
        ([$scope_reqs[] | select(.impl_status == "done" and in_code(.id) and in_incomplete_feature(.id)) |
          {req_id: .id, type: "partial_implementation", priority: .priority, suggested_action: ("Complete feature for " + .id), w003: true}]
        ) +
        # Orphan code
        ([$orphans[] | {req_id: null, file: ., type: "orphan_code", priority: "medium", suggested_action: "Add REQ-ID comment or classify as utility"}]
        ) +
        # Not started with code (rare)
        ([$scope_reqs[] | select(.impl_status == "not_started" and in_code(.id)) |
          {req_id: .id, type: "partial_implementation", priority: .priority, suggested_action: ("Update impl_status for " + .id + " or remove code"), has_code_without_status: true}]
        )
      ),
      "analysis_metadata": {
        "generated_at": "'"$(get_timestamp)"'",
        "registry_path": "'"$REGISTRY_FILE"'",
        "scan_results_file": "'"$SCAN_RESULTS_FILE"'"
      }
    }
  ' > "$OUTPUT_FILE"

  # Read back summary for logging
  local impl_count w001_count w002_count w003_count sync_rate
  impl_count=$(jq -r '.implemented | length' "$OUTPUT_FILE")
  w001_count=$(jq -r '.w001_anomalies | length' "$OUTPUT_FILE")
  w002_count=$(jq -r '.w002_anomalies | length' "$OUTPUT_FILE")
  w003_count=$(jq -r '.w003_anomalies | length' "$OUTPUT_FILE")
  sync_rate=$(jq -r '.sync_rate // "N/A"' "$OUTPUT_FILE")

  info "Analysis complete: $impl_count implemented, W001=$w001_count, W002=$w002_count, W003=$w003_count, sync_rate=$sync_rate%"
  info "Output: $OUTPUT_FILE"
}

main
