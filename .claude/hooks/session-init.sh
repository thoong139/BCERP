#!/usr/bin/env bash
# session-init.sh — Detect project state on startup, inject context
# Triggered: SessionStart
# READ-ONLY — không modify bất kỳ file nào
#
# Detects:
# - .mc-data/ exists?
# - Current phase (scan doc dirs)
# - Last checkpoint file
# - Project name from registry
#
# Output: summary to stderr (visible context for Claude)

set -euo pipefail

HOOK_NAME="session-init"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utils if available (fail-open if not)
if [[ -f "$SCRIPT_DIR/_hook-utils.sh" ]]; then
  source "$SCRIPT_DIR/_hook-utils.sh"
fi

# ============================================================
# DETECT: .mc-data/ exists?
# ============================================================

MCV3_HAS_DATA="0"
MCV3_CURRENT_PHASE=""
MCV3_LAST_CHECKPOINT=""
MCV3_PROJECT_NAME=""

if [[ ! -d ".mc-data" ]]; then
  # No project data — silent exit (fresh project or not a MCV3 project)
  exit 0
fi

MCV3_HAS_DATA="1"

# ============================================================
# DETECT: Current phase (latest phase dir with docs)
# ============================================================

PHASE_ORDER=(
  "phase6-deployment"
  "phase5-implementation"
  "phase4-ux"
  "phase3-architecture"
  "phase2-features"
  "phase1-business"
  "phase0-brainstorm"
)

for phase in "${PHASE_ORDER[@]}"; do
  if [[ -d ".mc-data/docs/$phase" ]]; then
    DOC_COUNT=$(find ".mc-data/docs/$phase" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$DOC_COUNT" -gt 0 ]]; then
      MCV3_CURRENT_PHASE="$phase"
      break
    fi
  fi
done

# ============================================================
# DETECT: Last checkpoint file
# ============================================================

LAST_CP_FILE=""
LAST_CP_MTIME=0

while IFS= read -r -d '' cp_file; do
  if [[ -f "$cp_file" ]]; then
    # Get modification time (cross-platform)
    if stat --version &>/dev/null 2>&1; then
      # GNU stat
      cp_mtime=$(stat -c %Y "$cp_file" 2>/dev/null || echo "0")
    else
      # BSD/macOS stat or fallback
      cp_mtime=$(stat -f %m "$cp_file" 2>/dev/null || echo "0")
    fi
    if [[ "$cp_mtime" -gt "$LAST_CP_MTIME" ]]; then
      LAST_CP_MTIME="$cp_mtime"
      LAST_CP_FILE="$cp_file"
    fi
  fi
done < <(find ".mc-data/work" -name "checkpoint.json" -type f -print0 2>/dev/null)

if [[ -n "$LAST_CP_FILE" ]]; then
  # Extract checkpoint_id if jq is available
  if command -v jq &>/dev/null; then
    MCV3_LAST_CHECKPOINT=$(jq -r '.checkpoint_id // .checkpoint_id // ""' "$LAST_CP_FILE" 2>/dev/null || true)
  fi
  [[ -z "$MCV3_LAST_CHECKPOINT" ]] && MCV3_LAST_CHECKPOINT="$(basename "$(dirname "$LAST_CP_FILE")")/checkpoint.json"
fi

# ============================================================
# DETECT: Project name from req-registry.json
# ============================================================

REGISTRY=".mc-data/docs/_meta/req-registry.json"
if [[ -f "$REGISTRY" ]] && command -v jq &>/dev/null; then
  MCV3_PROJECT_NAME=$(jq -r '.project.name // .project_name // ""' "$REGISTRY" 2>/dev/null || true)
fi

# ============================================================
# OUTPUT: Context summary to stderr (visible to Claude)
# Claude Code SessionStart hooks không inject env vars từ stdout.
# Toàn bộ context được output qua stderr để Claude đọc trực tiếp.
# ============================================================

echo "" >&2
echo "=== MCV3 Session Context ===" >&2
echo "Project data: $([ "$MCV3_HAS_DATA" = "1" ] && echo "found (.mc-data/)" || echo "not found")" >&2
[[ -n "$MCV3_CURRENT_PHASE" ]] && echo "Current phase: $MCV3_CURRENT_PHASE" >&2
[[ -n "$MCV3_LAST_CHECKPOINT" ]] && echo "Last checkpoint: $MCV3_LAST_CHECKPOINT" >&2
[[ -n "$MCV3_PROJECT_NAME" ]] && echo "Project: $MCV3_PROJECT_NAME" >&2
echo "============================" >&2
echo "" >&2

exit 0
