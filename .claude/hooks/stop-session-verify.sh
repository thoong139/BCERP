#!/bin/bash
# ============================================
# Hook: stop-session-verify.sh
# Purpose: Verify trước khi session kết thúc
# Trigger: Stop
# ============================================

set -euo pipefail

source "$(dirname "$0")/_hook-utils.sh"
JQ_BIN=$(hook_resolve_jq || true)
WARNINGS=0
# Excluded dirs: không phải skill work dirs (không tạo checkpoint)
EXCLUDED_WORK_DIRS=("shared-metrics")

print_sep() {
  echo "====================================================" >&2
}

echo "" >&2
print_sep
echo "DEVKIT Session End Verification" >&2
print_sep
echo "" >&2

# ============================================
# PRE-CHECK: Checkpoint Auto-Save
# Scan skill work dirs với JSON activity nhưng chưa có checkpoint → auto-save minimal checkpoint
# Trigger: skill dir có ≥1 JSON file (root level) + không có checkpoint.json
# Goal: tránh mất trạng thái khi session kết thúc giữa chừng
# ============================================

if [[ -n "$JQ_BIN" ]] && [[ -d ".mc-data/work" ]]; then
  AUTO_SAVED=0

  while IFS= read -r -d '' skill_dir; do
    SKILL_NAME="$(basename "$skill_dir")"
    CHECKPOINT_FILE="${skill_dir}/checkpoint.json"

    # Skip excluded non-skill directories
    SKIP=0
    for excl in "${EXCLUDED_WORK_DIRS[@]}"; do
      [[ "$SKILL_NAME" == "$excl" ]] && SKIP=1 && break
    done
    [[ "$SKIP" -eq 1 ]] && continue

    # Skip if checkpoint already exists
    if [[ -f "$CHECKPOINT_FILE" ]]; then
      continue
    fi

    # Skip if no JSON files at root level (skill not active)
    JSON_COUNT=$(find "$skill_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$JSON_COUNT" -eq 0 ]]; then
      continue
    fi

    # Generate checkpoint_id: CP-YYYYMMDD-000 (000 = auto-save slot)
    CP_DATE=$(date "+%Y%m%d" 2>/dev/null || echo "00000000")
    CP_ID="CP-${CP_DATE}-000"

    # Build minimal checkpoint (required fields từ checkpoint-schema.json)
    CHECKPOINT_JSON=$("$JQ_BIN" -cn \
      --arg cp_id "$CP_ID" \
      --arg skill_id "$SKILL_NAME" \
      --arg saved_at "$(date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z")" \
      '{
        checkpoint_id: $cp_id,
        skill_id: $skill_id,
        phase: "auto-saved",
        saved_at: $saved_at,
        next_action: "resume-from-auto-checkpoint",
        _auto_saved: true
      }' 2>/dev/null || echo "")

    if [[ -z "$CHECKPOINT_JSON" ]]; then
      echo "WARNING Auto-checkpoint: jq build failed for $SKILL_NAME" >&2
      continue
    fi

    # Validate required fields (jq-based, không cần ajv)
    VALID=$("$JQ_BIN" -n \
      --argjson cp "$CHECKPOINT_JSON" \
      '($cp.checkpoint_id != null) and ($cp.skill_id != null) and ($cp.phase != null) and ($cp.saved_at != null) and ($cp.next_action != null)' \
      2>/dev/null || echo "false")

    if [[ "$VALID" != "true" ]]; then
      echo "WARNING Auto-checkpoint: validation failed for $SKILL_NAME — skipping" >&2
      continue
    fi

    # Write checkpoint
    echo "$CHECKPOINT_JSON" > "$CHECKPOINT_FILE"
    echo "INFO Auto-checkpoint saved: $SKILL_NAME → $CHECKPOINT_FILE" >&2
    AUTO_SAVED=$((AUTO_SAVED + 1))

  done < <(find ".mc-data/work" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  if [[ "$AUTO_SAVED" -gt 0 ]]; then
    echo "INFO $AUTO_SAVED auto-checkpoint(s) saved" >&2
  fi
fi

echo "" >&2

# ============================================
# CHECK 1: Uncommitted Changes
# ============================================

if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
  CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$CHANGES" -gt 0 ]]; then
    echo "WARNING Uncommitted Changes: $CHANGES file(s)" >&2
    echo "  Run 'git status' để rà soát" >&2
    echo "" >&2
    WARNINGS=$((WARNINGS + 1))
  else
    echo "OK Git working tree sạch" >&2
  fi
else
  echo "INFO Không phải git repository" >&2
fi

# ============================================
# CHECK 2: REQ-ID Sync Status
# ============================================

SYNC_FILE=".mc-data/sync/sync-status.md"
if [[ -f "$SYNC_FILE" ]]; then
  SYNC_RATE=$(grep -oE "Sync Rate.*[0-9]+%" "$SYNC_FILE" | head -1 | grep -oE "[0-9]+%" | tr -d '%' || true)

  if [[ -n "$SYNC_RATE" ]]; then
    if [[ "$SYNC_RATE" -lt 100 ]]; then
      echo "WARNING REQ-ID Sync Rate: ${SYNC_RATE}%" >&2
      echo "  Run '/wf-verify-sync' để xem chi tiết" >&2
      echo "" >&2
      WARNINGS=$((WARNINGS + 1))
    else
      echo "OK REQ-ID Sync Rate: 100%" >&2
    fi
  fi
fi

# ============================================
# CHECK 3: Knowledge Base Status
# ============================================

KB_DIR=".mc-data/knowledge-base"
if [[ -d "$KB_DIR" ]]; then
  KB_FILES=$(find "$KB_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "INFO Knowledge Base: $KB_FILES file(s)" >&2
else
  echo "INFO Knowledge Base chưa được khởi tạo" >&2
fi

# ============================================
# CHECK 4: Requirements Status
# ============================================

REQ_DIR=".mc-data/docs/phase1-business/departments"
if [[ -d "$REQ_DIR" ]]; then
  REQ_FILES=$(find "$REQ_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "INFO Requirements: $REQ_FILES file(s)" >&2
elif [[ -f ".mc-data/docs/_meta/req-registry.json" ]]; then
  echo "INFO Requirements: req-registry.json exists" >&2
else
  echo "INFO Requirements chưa được khởi tạo" >&2
fi

# ============================================
# CHECK 5: Hook Metrics Summary
# ============================================

if [[ -n "$JQ_BIN" ]] && hook_metric_file_exists; then
  METRICS_SUMMARY=$(hook_render_metrics_summary || true)

  if [[ -n "$METRICS_SUMMARY" ]]; then
    TOTAL_EVENTS=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.total_events // 0')
    POST_WRITES=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.post_write_invocations // 0')
    INCREMENTAL_CHECKS=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.incremental_contract_checks // 0')
    FULL_SCANS=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.full_contract_checks // 0')
    SYNC_UPDATES=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.sync_updates // 0')
    PHASES=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '(.phases_touched // []) | join(", ")')
    LAST_HOOK=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.last_event.hook // "n/a"')
    LAST_PHASE=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.last_event.phase // "n/a"')
    LAST_TIER=$(echo "$METRICS_SUMMARY" | "$JQ_BIN" -r '.last_event.tier // "n/a"')

    echo "INFO Hook Metrics (2-Tier Strategy): $TOTAL_EVENTS event(s)" >&2
    echo "  Post-write hooks: $POST_WRITES | Incremental: $INCREMENTAL_CHECKS | Full scans: $FULL_SCANS | Sync updates: $SYNC_UPDATES" >&2
    if [[ -n "$PHASES" ]]; then
      echo "  Phases touched: $PHASES" >&2
    fi
    echo "  Last event: $LAST_HOOK (Tier $LAST_TIER, $LAST_PHASE)" >&2
  fi
elif [[ "${MCV3_HOOK_METRICS_ENABLED:-0}" == "1" ]]; then
  echo "INFO Hook metrics đã bật nhưng chưa có dữ liệu" >&2
fi

# ============================================
# SUMMARY
# ============================================

echo "" >&2
print_sep
if [[ "$WARNINGS" -gt 0 ]]; then
  echo "WARNING $WARNINGS vấn đề cần rà soát trước khi kết thúc session" >&2
else
  echo "OK Không phát hiện vấn đề chặn kết thúc session" >&2
fi
print_sep
echo "" >&2

exit 0
