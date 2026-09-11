#!/usr/bin/env bash
# Build scope-impact.json artifact (schema scope-impact-v1)
# Usage: bash as-scope-impact-build.sh <session_dir>
# Output: writes $SESSION_DIR/scope-impact.json + prints JSON summary
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

SESSION_DIR="${1:?Usage: as-scope-impact-build.sh <session_dir>}"

require_jq

STATUS_FILE="$SESSION_DIR/add-scope-status.json"
SPEC_FILE="$SESSION_DIR/scope-spec.json"
OUTPUT_FILE="$SESSION_DIR/scope-impact.json"

# Graceful defaults nếu files chưa đầy đủ
SCOPE_ID="${SESSION_DIR##*/}"
TARGET_SYSTEM=""
MODE="interactive"
LEGACY=false
MODS_BEFORE=0
MODS_AFTER=0
FEATS_BEFORE=0
FEATS_AFTER=0
CHECKSUM_PRE=""
BACKUP=""
MODS_ADDED="[]"
MODS_SKIPPED="[]"
FEATS_ADDED_COUNT=0

if [[ -f "$STATUS_FILE" ]]; then
  TARGET_SYSTEM=$(jq -r '.target_system // ""' "$STATUS_FILE" 2>/dev/null || echo "")
  MODE=$(jq -r '.mode // "interactive"' "$STATUS_FILE" 2>/dev/null || echo "interactive")
  LEGACY=$(jq '.legacy_mode // false' "$STATUS_FILE" 2>/dev/null || echo "false")
  MODS_BEFORE=$(jq '.summary.modules_before // 0' "$STATUS_FILE" 2>/dev/null || echo "0")
  MODS_AFTER=$(jq '.summary.modules_after // 0' "$STATUS_FILE" 2>/dev/null || echo "0")
  FEATS_BEFORE=$(jq '.summary.features_before // 0' "$STATUS_FILE" 2>/dev/null || echo "0")
  FEATS_AFTER=$(jq '.summary.features_after // 0' "$STATUS_FILE" 2>/dev/null || echo "0")
  CHECKSUM_PRE=$(jq -r '.audit_chain.checksum_pre // ""' "$STATUS_FILE" 2>/dev/null || echo "")
  BACKUP=$(jq -r '.summary.registry_backup // ""' "$STATUS_FILE" 2>/dev/null || echo "")
fi

if [[ -f "$SPEC_FILE" ]]; then
  MODS_ADDED=$(jq '[.modules_to_add[]?.id // empty] // []' "$SPEC_FILE" 2>/dev/null || echo "[]")
  MODS_SKIPPED=$(jq '[.existing_conflicts[]? | select(.action=="skip") | {id:.entry_id,reason:.reason}] // []' "$SPEC_FILE" 2>/dev/null || echo "[]")
  FEATS_ADDED_COUNT=$(jq '.features_to_add | length // 0' "$SPEC_FILE" 2>/dev/null || echo "0")
fi

# Checksum post (current state của registry)
CHECKSUM_POST=""
if [[ -f "$REGISTRY_PATH" ]]; then
  CHECKSUM_POST=$(sha_hash "$REGISTRY_PATH")
fi

# Files created — scan phase2-features nếu có
FILES_CREATED="[]"
if [[ -d ".mc-data/docs/phase2-features" ]]; then
  SYSTEM_SLUG=$(echo "$TARGET_SYSTEM" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/^sys-//')
  if [[ -n "$SYSTEM_SLUG" ]]; then
    FILES_CREATED=$(find ".mc-data/docs/phase2-features/$SYSTEM_SLUG" -name "*.md" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")
  fi
fi

# Consumer hints (P0-3 fix: use jq instead of string interpolation for JSON safety)
STUBS_GLOB="[]"
if [[ -n "$TARGET_SYSTEM" ]]; then
  SYS_SLUG=$(echo "$TARGET_SYSTEM" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/^sys-//')
  STUBS_GLOB=$(jq -n --arg slug "$SYS_SLUG" '[$slug + "/**"]')
fi

# Build JSON artifact
jq -n \
  --arg schema "scope-impact-v1" \
  --arg scope_id "$SCOPE_ID" \
  --arg target_system "$TARGET_SYSTEM" \
  --arg mode "$MODE" \
  --argjson legacy "$LEGACY" \
  --arg ts "$(get_timestamp)" \
  --argjson mods_added "$MODS_ADDED" \
  --argjson mods_skipped "$MODS_SKIPPED" \
  --argjson feats_added_count "$FEATS_ADDED_COUNT" \
  --argjson mods_before "$MODS_BEFORE" \
  --argjson mods_after "$MODS_AFTER" \
  --argjson feats_before "$FEATS_BEFORE" \
  --argjson feats_after "$FEATS_AFTER" \
  --arg checksum_pre "$CHECKSUM_PRE" \
  --arg checksum_post "$CHECKSUM_POST" \
  --arg backup "$BACKUP" \
  --argjson files_created "$FILES_CREATED" \
  --argjson stubs_glob "$STUBS_GLOB" \
  '{
    "$schema": $schema,
    scope_id: $scope_id,
    target_system: $target_system,
    mode: $mode,
    legacy_mode: $legacy,
    timestamp: $ts,
    registry_changes: {
      modules_added: $mods_added,
      modules_skipped: $mods_skipped,
      features_added_count: ($feats_added_count | tonumber),
      features_skipped_count: 0,
      modules_count_before: ($mods_before | tonumber),
      modules_count_after: ($mods_after | tonumber),
      features_count_before: ($feats_before | tonumber),
      features_count_after: ($feats_after | tonumber)
    },
    files_created: $files_created,
    audit_chain: {
      checksum_pre: (if ($checksum_pre == "" or $checksum_pre == "no-checksum") then null else ("sha256:" + $checksum_pre) end),
      checksum_post: (if ($checksum_post == "" or $checksum_post == "no-checksum") then null else ("sha256:" + $checksum_post) end),
      backup_path: $backup
    },
    consumer_hints: {
      "wf-define-features": {
        stubs_to_flesh: $stubs_glob,
        total_stub_features: ($feats_added_count | tonumber)
      },
      "wf-plan-modules": {
        new_modules_to_plan: $mods_added,
        replan_recommended: true
      },
      "wf-annotate-code": {
        new_modules_to_annotate: (if $legacy then $mods_added else [] end)
      },
      "wf-verify-sync": {
        registry_changes_version: $schema,
        cross_check_fields: ["registry_changes.modules_added", "files_created"]
      },
      "wf-preflight": {
        affected_files_count: ($files_created | length),
        risk_level: (
          if ($feats_added_count | tonumber) > 30 then "high"
          elif ($feats_added_count | tonumber) >= 10 then "medium"
          else "low"
          end
        )
      }
    }
  }' > "$OUTPUT_FILE"

# Validate schema
jq -e '."$schema" == "scope-impact-v1"' "$OUTPUT_FILE" > /dev/null 2>&1 || {
  echo "{\"error\":\"schema_validation_failed\",\"output\":\"$OUTPUT_FILE\"}"
  exit 1
}
jq -e '.registry_changes.modules_count_after >= .registry_changes.modules_count_before' "$OUTPUT_FILE" > /dev/null 2>&1 || {
  echo "{\"warning\":\"count_invariant_violated\",\"output\":\"$OUTPUT_FILE\"}"
}

echo "{\"status\":\"built\",\"output\":\"$OUTPUT_FILE\",\"modules_added\":$(echo "$MODS_ADDED" | jq 'length' 2>/dev/null || echo 0),\"features_added\":$FEATS_ADDED_COUNT}"
