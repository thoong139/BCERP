#!/usr/bin/env bash
# Validate registry: jq parse + count assertions sau khi write
# Usage: bash as-validate-registry.sh <session_dir> [delta_mods] [delta_feats]
# Output: JSON {pass, modules, features, systems, errors[]}
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/as-common.sh"

SESSION_DIR="${1:?Usage: as-validate-registry.sh <session_dir> [delta_mods] [delta_feats]}"
EXPECT_MODS_DELTA="${2:-0}"    # +N modules expected to be added
EXPECT_FEATS_DELTA="${3:-0}"   # +N features expected to be added

require_jq

ERRORS=()

# T1: File exists + non-empty
if ! test -s "$REGISTRY_PATH"; then
  ERRORS+=("T1_FAIL: registry missing or empty at $REGISTRY_PATH")
fi

# JSON valid parse
if ! jq '.' "$REGISTRY_PATH" > /dev/null 2>&1; then
  ERRORS+=("JSON_INVALID: registry parse error")
  ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
  echo "{\"pass\":false,\"errors\":$ERRORS_JSON}"
  exit 1
fi

# Count current values
MODS_COUNT=$(jq '.modules | length' "$REGISTRY_PATH")
FEATS_COUNT=$(jq '.features | length' "$REGISTRY_PATH")
SYS_COUNT=$(jq '.systems | length' "$REGISTRY_PATH")

# Load before counts từ session status (nếu có)
if [[ -f "$SESSION_DIR/add-scope-status.json" ]]; then
  MODS_BEFORE=$(jq '.summary.modules_before // 0' "$SESSION_DIR/add-scope-status.json" 2>/dev/null || echo "0")
  FEATS_BEFORE=$(jq '.summary.features_before // 0' "$SESSION_DIR/add-scope-status.json" 2>/dev/null || echo "0")
  SYS_BEFORE=$(jq '.summary.systems_before // 0' "$SESSION_DIR/add-scope-status.json" 2>/dev/null || echo "0")
else
  # Không có session status → chỉ validate JSON structure
  MODS_BEFORE=$MODS_COUNT
  FEATS_BEFORE=$FEATS_COUNT
  SYS_BEFORE=$SYS_COUNT
fi

# Delta assertions (chỉ check khi delta != 0)
if [[ "$EXPECT_MODS_DELTA" -ne 0 ]]; then
  EXPECT_MODS=$((MODS_BEFORE + EXPECT_MODS_DELTA))
  if [[ "$MODS_COUNT" -ne "$EXPECT_MODS" ]]; then
    ERRORS+=("MODULES_COUNT_MISMATCH: got=$MODS_COUNT expected=$EXPECT_MODS (before=$MODS_BEFORE delta=$EXPECT_MODS_DELTA)")
  fi
fi

if [[ "$EXPECT_FEATS_DELTA" -ne 0 ]]; then
  EXPECT_FEATS=$((FEATS_BEFORE + EXPECT_FEATS_DELTA))
  if [[ "$FEATS_COUNT" -ne "$EXPECT_FEATS" ]]; then
    ERRORS+=("FEATURES_COUNT_MISMATCH: got=$FEATS_COUNT expected=$EXPECT_FEATS (before=$FEATS_BEFORE delta=$EXPECT_FEATS_DELTA)")
  fi
fi

# Systems count không được thay đổi (wf-add-scope chỉ APPEND modules/features)
if [[ "$EXPECT_MODS_DELTA" -ne 0 || "$EXPECT_FEATS_DELTA" -ne 0 ]]; then
  if [[ "$SYS_COUNT" -ne "$SYS_BEFORE" ]]; then
    ERRORS+=("SYSTEMS_CHANGED: got=$SYS_COUNT expected=$SYS_BEFORE (systems should not change in add-scope)")
  fi
  # P1-11 fix: Identity verification — ensure no existing module IDs were lost
  if [[ -f "$SESSION_DIR/add-scope-status.json" ]]; then
    BACKUP_PATH=$(jq -r '.summary.registry_backup // ""' "$SESSION_DIR/add-scope-status.json" 2>/dev/null || echo "")
    if [[ -n "$BACKUP_PATH" && -f "$BACKUP_PATH" ]]; then
      EXISTING_IDS=$(jq -r '.modules[]?.id // empty' "$BACKUP_PATH" 2>/dev/null | sort)
      CURRENT_IDS=$(jq -r '.modules[]?.id // empty' "$REGISTRY_PATH" 2>/dev/null | sort)
      if [[ -n "$EXISTING_IDS" ]]; then
        MISSING=$(comm -23 <(echo "$EXISTING_IDS") <(echo "$CURRENT_IDS"))
        if [[ -n "$MISSING" ]]; then
          ERRORS+=("MODULES_LOST: existing IDs missing after write: $MISSING")
        fi
      fi
    fi
  fi
fi

if [[ ${#ERRORS[@]} -eq 0 ]]; then
  echo "{\"pass\":true,\"modules\":$MODS_COUNT,\"features\":$FEATS_COUNT,\"systems\":$SYS_COUNT}"
else
  ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
  echo "{\"pass\":false,\"modules\":$MODS_COUNT,\"features\":$FEATS_COUNT,\"systems\":$SYS_COUNT,\"errors\":$ERRORS_JSON}"
  exit 1
fi
