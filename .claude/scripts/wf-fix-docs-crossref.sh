#!/usr/bin/env bash
# wf-fix-docs-crossref.sh — Bidirectional docs sync verification (v7.0 S8)
#
# Soft warning (KHÔNG block POST-GATE) — feedback signal cho wf-verify-sync consume.
#
# Usage:
#   wf-fix-docs-crossref.sh --session-dir <path> [--output <path>]
#
# Inputs (read-only):
#   $SESSION_DIR/fix-log.json — REQUIRED (fix entries với files_modified[])
#   git diff (HEAD~N..HEAD or working tree) — feature spec changes
#
# Output:
#   $SESSION_DIR/docs-sync-report.json (default) or --output path
#
# Exit codes:
#   0 — luôn exit 0 (warning only, không block)
#   1 — invalid args / session-dir not found / required input missing
#
# Bidirectional check:
#   - Forward: fix-log entry update phase2-features/[feat].md → verify file thực sự changed (git)
#   - Reverse: feature spec git diff thay đổi → verify có corresponding fix-log entry
#
# Mismatches[] có 2 type:
#   - "missing_git_diff"    — fix-log nói update but git không thấy change
#   - "orphan_git_change"   — git diff thay đổi feature spec but không có fix-log entry

set -euo pipefail

# Source common helpers
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
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "ERROR: --session-dir required" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: session-dir not found: $SESSION_DIR" >&2; exit 1; }

OUTPUT="${OUTPUT:-$SESSION_DIR/docs-sync-report.json}"
SESSION_ID=$(basename "$SESSION_DIR")

FIX_LOG="$SESSION_DIR/fix-log.json"
[ -s "$FIX_LOG" ] || { echo "ERROR: fix-log.json missing or empty: $FIX_LOG" >&2; exit 1; }

# Strip CRLF (Windows Git Bash robustness)
FIX_LOG_CONTENT=$(tr -d '\r' < "$FIX_LOG")

# ============================================================
# COLLECT FORWARD CLAIMS — fix-log entries[] với files_modified[] containing docs paths
# ============================================================
# Patterns we care: phase2-features/, phase4-ux/
CLAIMED_DOC_FILES=$(jq -c '
  [
    .entries[]? |
    {
      issue_id: (.issue_id // null),
      iteration: (.iteration // 0),
      files: [(.files_modified // [])[]? | select(. != null and (test("\\.mc-data/docs/(phase2-features|phase4-ux)/")))]
    } |
    select(.files | length > 0)
  ]
' <<< "$FIX_LOG_CONTENT" 2>/dev/null || echo '[]')

CLAIMED_COUNT=$(jq 'length' <<< "$CLAIMED_DOC_FILES")

# Flat unique list of claimed doc files
CLAIMED_FLAT=$(jq -c '[.[] | .files[]] | unique' <<< "$CLAIMED_DOC_FILES")

# ============================================================
# COLLECT REVERSE — git diff feature/UX spec changes (best-effort)
# ============================================================
GIT_AVAILABLE=true
GIT_CHANGED_DOCS='[]'

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  GIT_AVAILABLE=false
  GIT_REASON="not_a_git_repo"
elif ! command -v git > /dev/null 2>&1; then
  GIT_AVAILABLE=false
  GIT_REASON="git_not_installed"
fi

if [ "$GIT_AVAILABLE" = "true" ]; then
  # Working tree changes (modified + untracked) trong phase2/phase4 dirs
  GIT_RAW=$(git status --porcelain 2>/dev/null | awk '{print $NF}' | grep -E '\.mc-data/docs/(phase2-features|phase4-ux)/' || true)

  if [ -n "$GIT_RAW" ]; then
    GIT_CHANGED_DOCS=$(printf '%s\n' "$GIT_RAW" | jq -R . | jq -sc 'unique')
  fi
fi

GIT_CHANGED_COUNT=$(jq 'length' <<< "$GIT_CHANGED_DOCS")

# ============================================================
# COMPUTE MISMATCHES
# ============================================================
MISMATCHES='[]'

# Forward: claimed files but no git diff (chỉ check khi git available)
if [ "$GIT_AVAILABLE" = "true" ] && [ "$CLAIMED_COUNT" -gt 0 ]; then
  MISSING_DIFF=$(jq -nc \
    --argjson claimed "$CLAIMED_FLAT" \
    --argjson git "$GIT_CHANGED_DOCS" \
    '$claimed - $git' 2>/dev/null || echo '[]')

  MISSING_COUNT=$(jq 'length' <<< "$MISSING_DIFF")
  MISSING_COUNT="${MISSING_COUNT:-0}"
  if [ "$MISSING_COUNT" -gt 0 ]; then
    while IFS= read -r f; do
      f=$(printf '%s' "$f" | tr -d '\r')
      [ -z "$f" ] && continue
      # Find which fix-log entry claimed this file
      ISSUE_REF=$(jq -r --arg f "$f" '
        [.[] | select(.files[]? == $f) | .issue_id] | .[0] // "unknown"
      ' <<< "$CLAIMED_DOC_FILES")
      MISMATCHES=$(jq -c \
        --arg type "missing_git_diff" \
        --arg path "$f" \
        --arg issue "$ISSUE_REF" \
        --arg detail "Fix-log entry claims update doc file but git status không thấy thay đổi" \
        '. += [{type: $type, path: $path, issue_ref: $issue, detail: $detail}]' <<< "$MISMATCHES")
    done < <(jq -r '.[]' <<< "$MISSING_DIFF")
  fi
fi

# Reverse: git diff doc changes but no fix-log entry (chỉ check khi git available)
if [ "$GIT_AVAILABLE" = "true" ] && [ "$GIT_CHANGED_COUNT" -gt 0 ]; then
  ORPHAN_DIFF=$(jq -nc \
    --argjson git "$GIT_CHANGED_DOCS" \
    --argjson claimed "$CLAIMED_FLAT" \
    '$git - $claimed' 2>/dev/null || echo '[]')

  ORPHAN_COUNT=$(jq 'length' <<< "$ORPHAN_DIFF")
  ORPHAN_COUNT="${ORPHAN_COUNT:-0}"
  if [ "$ORPHAN_COUNT" -gt 0 ]; then
    while IFS= read -r f; do
      f=$(printf '%s' "$f" | tr -d '\r')
      [ -z "$f" ] && continue
      MISMATCHES=$(jq -c \
        --arg type "orphan_git_change" \
        --arg path "$f" \
        --arg detail "Git status thay đổi feature/UX spec nhưng KHÔNG có fix-log entry tương ứng" \
        '. += [{type: $type, path: $path, issue_ref: null, detail: $detail}]' <<< "$MISMATCHES")
    done < <(jq -r '.[]' <<< "$ORPHAN_DIFF")
  fi
fi

MISMATCH_COUNT=$(jq 'length' <<< "$MISMATCHES")

# ============================================================
# Determine status
# ============================================================
if [ "$GIT_AVAILABLE" = "false" ]; then
  STATUS="skipped"
  REASON="${GIT_REASON:-unknown}"
elif [ "$MISMATCH_COUNT" -eq 0 ]; then
  STATUS="passed"
  REASON="all_in_sync"
else
  STATUS="warning"
  REASON="${MISMATCH_COUNT}_mismatches_detected"
fi

# ============================================================
# ASSEMBLE final JSON
# ============================================================
RAN_AT=$(iso_now)

FINAL_JSON=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg ran "$RAN_AT" \
  --arg status "$STATUS" \
  --arg reason "$REASON" \
  --argjson git "$GIT_AVAILABLE" \
  --argjson claimed_count "$CLAIMED_COUNT" \
  --argjson git_count "$GIT_CHANGED_COUNT" \
  --argjson claimed "$CLAIMED_FLAT" \
  --argjson git_changed "$GIT_CHANGED_DOCS" \
  --argjson mismatches "$MISMATCHES" \
  '{
    "$schema": "docs-sync-report-v1",
    session_id: $sid,
    ran_at: $ran,
    status: $status,
    reason: $reason,
    git_available: $git,
    summary: {
      claimed_doc_files_count: $claimed_count,
      git_changed_docs_count: $git_count,
      mismatches_count: ($mismatches | length)
    },
    claimed_doc_files: $claimed,
    git_changed_docs: $git_changed,
    mismatches: $mismatches
  }')

# ============================================================
# WRITE atomic + validate
# ============================================================
atomic_write_json "$OUTPUT" "$FINAL_JSON" || { echo "ERROR: atomic_write_json failed" >&2; exit 1; }

SCHEMA=$(jq -r '."$schema"' "$OUTPUT")
[ "$SCHEMA" = "docs-sync-report-v1" ] || { echo "ERROR: schema mismatch in output: $SCHEMA" >&2; exit 1; }

echo "OK: docs-sync-report.json generated → $OUTPUT" >&2
echo "    status=$STATUS claimed=$CLAIMED_COUNT git_changed=$GIT_CHANGED_COUNT mismatches=$MISMATCH_COUNT" >&2

if [ "$MISMATCH_COUNT" -gt 0 ]; then
  echo "WARN: docs sync mismatches detected (soft signal — không block POST-GATE)" >&2
  jq '.mismatches' "$OUTPUT" >&2
fi

# Always exit 0 — soft warning only
exit 0
