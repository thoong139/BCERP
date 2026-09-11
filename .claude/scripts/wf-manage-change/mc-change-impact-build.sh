#!/usr/bin/env bash
# mc-change-impact-build.sh — Build change-impact.json artifact from session data
# Usage: mc-change-impact-build.sh --session-dir=.mc-data/work/wf-manage-change/CHG-20260429-001
#
# Reads: change-status.json, affected-artifacts.json, req-registry.json
# Writes: $SESSION_DIR/change-impact.json
#
# Exit codes: 0 = success, 1 = error, 2 = invalid args

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

SESSION_DIR=""

for arg in "$@"; do
  case "$arg" in
    --session-dir=*) SESSION_DIR="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$SESSION_DIR" ]]; then
  mc_err "Usage: mc-change-impact-build.sh --session-dir=PATH"
  exit 2
fi

if [[ ! -f "$SESSION_DIR/change-status.json" ]]; then
  mc_err "change-status.json not found in: $SESSION_DIR"
  exit 1
fi

if ! mc_has_jq; then
  mc_err "jq required for mc-change-impact-build.sh"
  exit 1
fi

# ─── Read session data ──────────────────────────────────────

CHANGE_ID=$(jq -r '.change_id // "UNKNOWN"' "$SESSION_DIR/change-status.json")
CHANGE_TYPE=$(jq -r '.intake.change_type_confirmed // .intake.change_type_preliminary // "UNKNOWN"' "$SESSION_DIR/change-status.json")
RISK_LEVEL=$(jq -r '.impact_summary.risk_level // "UNKNOWN"' "$SESSION_DIR/change-status.json")

# ─── Build registry_changes from affected-artifacts.json ─────

REGISTRY_CHANGES='{}'
if [[ -f "$SESSION_DIR/affected-artifacts.json" ]]; then
  REGISTRY_CHANGES=$(jq '{
    requirements_updated: (.registry_changes.requirements_to_update // []),
    requirements_added: (.registry_changes.requirements_to_add // []),
    features_updated: (.registry_changes.features_to_update // []),
    features_added: (.registry_changes.features_to_add // []),
    features_deleted: (.registry_changes.features_to_delete // []),
    impl_status_changes: (.registry_changes.impl_status_updates // [])
  }' "$SESSION_DIR/affected-artifacts.json" 2>/dev/null || echo '{}')
fi

# ─── Build files_modified ────────────────────────────────────

FILES_MODIFIED=$(jq -r '
  if .phase4b.files_updated then
    if (.phase4b.files_updated | type) == "array" then .phase4b.files_updated else [] end
  else [] end
' "$SESSION_DIR/change-status.json" 2>/dev/null || echo '[]')

# ─── Build docs_modified ────────────────────────────────────

DOCS_MODIFIED=$(jq -r '
  if .phase4a.files_updated then
    if (.phase4a.files_updated | type) == "array" then .phase4a.files_updated else [] end
  else [] end
' "$SESSION_DIR/change-status.json" 2>/dev/null || echo '[]')

# ─── Checksum (audit chain) ─────────────────────────────────

REGISTRY=$(mc_registry_path)
CHECKSUM_POST=""
if [[ -f "$REGISTRY" ]]; then
  CHECKSUM_POST=$(mc_sha256 "$REGISTRY")
fi

# Find most recent backup (graceful: glob no-match → empty string, KHÔNG fail script)
BACKUP_PATH=""
# shellcheck disable=SC2012
BACKUP_PATH=$(ls -t "${REGISTRY}.pre-change-"* 2>/dev/null | head -1 || true)
CHECKSUM_PRE=""
if [[ -n "$BACKUP_PATH" && -f "$BACKUP_PATH" ]]; then
  CHECKSUM_PRE=$(mc_sha256 "$BACKUP_PATH")
fi

# ─── Build output ───────────────────────────────────────────

GENERATED_TS=$(mc_timestamp)

jq -n \
  --arg schema "change-impact-v1" \
  --arg cid "$CHANGE_ID" \
  --arg ctype "$CHANGE_TYPE" \
  --arg risk "$RISK_LEVEL" \
  --argjson reg_changes "$REGISTRY_CHANGES" \
  --argjson files "$FILES_MODIFIED" \
  --argjson docs "$DOCS_MODIFIED" \
  --arg pre_checksum "$CHECKSUM_PRE" \
  --arg post_checksum "$CHECKSUM_POST" \
  --arg backup "$BACKUP_PATH" \
  --arg generated_ts "$GENERATED_TS" \
  '{
    "$schema": $schema,
    change_id: $cid,
    change_type: $ctype,
    risk_level: $risk,
    registry_changes: $reg_changes,
    files_modified: $files,
    docs_modified: $docs,
    verify_evidence: { preflight_status: null, sync_rate: null, cross_validation_coverage: null },
    regression_check: { tests_passed: null, tests_failed: null, tests_total: null },
    audit_chain: { checksum_pre: $pre_checksum, checksum_post: $post_checksum, backup_path: $backup },
    generated_at: $generated_ts
  }' > "$SESSION_DIR/change-impact.json"

mc_log "change-impact.json built: $SESSION_DIR/change-impact.json"
