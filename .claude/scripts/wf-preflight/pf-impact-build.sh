#!/usr/bin/env bash
# pf-impact-build.sh — Build preflight-impact.json (schema preflight-impact-v1)
# Usage: pf-impact-build.sh <SESSION_DIR>
# Output: Writes SESSION_DIR/preflight-impact.json, echoes JSON {status, path, verdict}
# Reads: SESSION_DIR/preflight-status.json + SESSION_DIR/issues-raw.json (optional)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/pf-common.sh"

SESSION_DIR="${1:?Usage: pf-impact-build.sh <session_dir>}"
require_jq

STATUS_FILE="$SESSION_DIR/preflight-status.json"
ISSUES_FILE="$SESSION_DIR/issues-raw.json"
REPORT_FILE="$SESSION_DIR/preflight-report.md"
OUTPUT_FILE="$SESSION_DIR/preflight-impact.json"

# Validate inputs
if [[ ! -f "$STATUS_FILE" ]]; then
  echo "{\"error\":\"status_file_missing\",\"path\":\"$STATUS_FILE\"}"
  exit 1
fi

# Load session data
SESSION_ID=$(jq -r '.session_id // "unknown"' "$STATUS_FILE")
SCOPE_TYPE=$(jq -r '.scope.type // "all"' "$STATUS_FILE")
SCOPE_NAME_RAW=$(jq '.scope.name' "$STATUS_FILE")  # keep as JSON (null or "string")
VERDICT=$(jq -r '.verdict // "UNKNOWN"' "$STATUS_FILE")
FIX_APPLIED=$(jq -r '.flags.fix // false' "$STATUS_FILE")
TESTS_RUN=$(jq -r '.flags.run_tests // false' "$STATUS_FILE")

# Scores (may be null)
SCORE_REGISTRY=$(jq '.scores.registry' "$STATUS_FILE")
SCORE_DOCS=$(jq '.scores.docs' "$STATUS_FILE")
SCORE_CODE=$(jq '.scores.code_sync' "$STATUS_FILE")
SCORE_QUALITY=$(jq '.scores.quality' "$STATUS_FILE")
SCORE_TESTS=$(jq '.scores.tests' "$STATUS_FILE")
SCORE_OVERALL=$(jq '.scores.overall' "$STATUS_FILE")

# Issues (accumulate from issues-raw.json)
ISSUES="[]"
if [[ -f "$ISSUES_FILE" ]]; then
  ISSUES=$(cat "$ISSUES_FILE")
  # Validate it's a JSON array
  if ! echo "$ISSUES" | jq -e 'type == "array"' > /dev/null 2>&1; then
    warn "issues-raw.json is not a JSON array, using empty array"
    ISSUES="[]"
  fi
fi

# Count by severity
CRITICAL=$(echo "$ISSUES" | jq '[.[] | select(.severity=="critical")] | length')
HIGH=$(echo "$ISSUES"     | jq '[.[] | select(.severity=="high")] | length')
MEDIUM=$(echo "$ISSUES"   | jq '[.[] | select(.severity=="medium")] | length')
LOW=$(echo "$ISSUES"      | jq '[.[] | select(.severity=="low")] | length')
TOTAL=$((CRITICAL + HIGH + MEDIUM + LOW))

# Checksums for audit_chain
REG_HASH="unavailable"
RPT_HASH="unavailable"
if [[ -f "$REGISTRY_PATH" ]]; then
  REG_HASH=$(sha_hash "$REGISTRY_PATH")
fi
if [[ -f "$REPORT_FILE" ]]; then
  RPT_HASH=$(sha_hash "$REPORT_FILE")
fi

# Determine next_recommended_action based on verdict
case "$VERDICT" in
  "FAIL")   NEXT_ACTION="Sửa các vấn đề critical/high trước khi tiếp tục development" ;;
  "WARN")   NEXT_ACTION="Review và xử lý các vấn đề medium/high, sau đó tiếp tục" ;;
  "PASS")   NEXT_ACTION="Sẵn sàng /wf-implement-feature hoặc /wf-prepare-deployment" ;;
  *)        NEXT_ACTION="" ;;
esac

# Build preflight-impact-v1 artifact
jq -n \
  --arg schema "preflight-impact-v1" \
  --arg sid "$SESSION_ID" \
  --arg scope_type "$SCOPE_TYPE" \
  --argjson scope_name "$SCOPE_NAME_RAW" \
  --arg verdict "$VERDICT" \
  --argjson score_reg "$SCORE_REGISTRY" \
  --argjson score_docs "$SCORE_DOCS" \
  --argjson score_code "$SCORE_CODE" \
  --argjson score_qual "$SCORE_QUALITY" \
  --argjson score_tests "$SCORE_TESTS" \
  --argjson score_overall "$SCORE_OVERALL" \
  --argjson critical "$CRITICAL" \
  --argjson high "$HIGH" \
  --argjson medium "$MEDIUM" \
  --argjson low "$LOW" \
  --argjson total "$TOTAL" \
  --argjson issues "$ISSUES" \
  --arg next_action "$NEXT_ACTION" \
  --argjson fix_applied "$FIX_APPLIED" \
  --argjson tests_run "$TESTS_RUN" \
  --arg reg_hash "sha256:$REG_HASH" \
  --arg rpt_hash "sha256:$RPT_HASH" \
  --arg ts "$(get_timestamp)" \
  '{
    schema: $schema,
    session_id: $sid,
    scope: {type: $scope_type, name: $scope_name},
    verdict: $verdict,
    scores: {
      registry: $score_reg,
      docs: $score_docs,
      code_sync: $score_code,
      quality: $score_qual,
      tests: $score_tests,
      overall: $score_overall
    },
    issues_by_category: {
      critical: $critical,
      high: $high,
      medium: $medium,
      low: $low,
      total: $total
    },
    issues: $issues,
    next_recommended_action: $next_action,
    blocking_items: [],
    registry_changes: [],
    fix_applied: $fix_applied,
    tests_run: $tests_run,
    audit_chain: {
      registry_checksum_sha256: $reg_hash,
      report_checksum_sha256: $rpt_hash,
      produced_at: $ts,
      by_skill_version: "wf-preflight@3.0.0"
    }
  }' > "$OUTPUT_FILE"

echo "{\"status\":\"built\",\"path\":\"$OUTPUT_FILE\",\"verdict\":\"$VERDICT\",\"total_issues\":$TOTAL}"
