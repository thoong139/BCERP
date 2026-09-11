#!/usr/bin/env bash
# wf-fix-safety-check.sh — Pre-Implementation Safety Gate cho /wf-fix-bugs (v7.0 S8)
#
# Usage:
#   wf-fix-safety-check.sh --session-dir <path> [--skip-uncommitted-check] [--output <path>]
#
# Inputs (read-only):
#   $SESSION_DIR/issue-registry.json       — REQUIRED (issue list từ triage)
#   $SESSION_DIR/fix-plan.md               — OPTIONAL (target entities trong fix plan)
#   $SESSION_DIR/cdg-tokens.json           — OPTIONAL (accept/reject từ CDG Handoff)
#   .mc-data/docs/_meta/req-registry.json  — OPTIONAL (registry xref check)
#   .mc-data/work/wf-brainstorm/legacy-decisions.json — OPTIONAL (DEPRECATED modules list)
#   git status                             — OPTIONAL (uncommitted changes check)
#
# Output:
#   $SESSION_DIR/safety-check.json (default) or --output path
#
# Exit codes:
#   0 — gates_passed=true, no blockers
#   1 — invalid args / session-dir not found
#   2 — required input missing (issue-registry.json)
#   3 — gates_passed=false, blockers present (orchestrator render CDG)
#
# 4 checks (per target arch §3.3):
#   1. code_collision_search    — entities/endpoints in fix-plan đã exist trong codebase
#   2. registry_xref            — All REQ-IDs/FEAT-IDs có trong req-registry.json
#   3. uncommitted_changes_check— git status có files trong target scope chưa commit
#   4. deprecated_modules_filter— issues KHÔNG touch DEPRECATED modules
#
# Behavior:
#   - status: "passed" | "warning" | "failed"
#   - "failed" → blockers[] non-empty → cdg_required=true, gates_passed=false, exit 3
#   - "warning" → warnings[] non-empty, gates_passed=true (nếu không có failed)

set -euo pipefail

# Source common helpers (atomic_write_json, json_escape, iso_now)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# ============================================================
# ARG PARSING
# ============================================================
SESSION_DIR=""
OUTPUT=""
SKIP_UNCOMMITTED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir)            SESSION_DIR="$2"; shift 2 ;;
    --output)                 OUTPUT="$2"; shift 2 ;;
    --skip-uncommitted-check) SKIP_UNCOMMITTED=true; shift ;;
    -h|--help)                sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "ERROR: --session-dir required" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: session-dir not found: $SESSION_DIR" >&2; exit 1; }

OUTPUT="${OUTPUT:-$SESSION_DIR/safety-check.json}"
SESSION_ID=$(basename "$SESSION_DIR")

ISSUE_REGISTRY="$SESSION_DIR/issue-registry.json"
FIX_PLAN="$SESSION_DIR/fix-plan.md"
CDG_TOKENS="$SESSION_DIR/cdg-tokens.json"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
REQ_REGISTRY="$REPO_ROOT/.mc-data/docs/_meta/req-registry.json"
LEGACY_DECISIONS="$REPO_ROOT/.mc-data/work/wf-brainstorm/legacy-decisions.json"

# Required input
[ -s "$ISSUE_REGISTRY" ] || { echo "ERROR: issue-registry.json missing or empty: $ISSUE_REGISTRY" >&2; exit 2; }

# ============================================================
# CHECK 1 — code_collision_search
# Tìm target entities (REQ-ID, FEAT-ID, file paths) từ issue-registry.
# Cho project có codebase: nếu fix-plan đã có "create" intent cho file
# đã tồn tại → collision (CDG required). Đối với "edit" intent → OK.
# ============================================================
COLLISION_STATUS="passed"
COLLISION_DETAILS="All target entities/endpoints exist in codebase or are net-new"
COLLISION_FILES='[]'

# Best-effort: extract files_target từ issue-registry.issues[].files_target[] nếu có
TARGET_FILES=$(jq -c '
  [.issues[] | (.files_target // [])[] | select(. != null and . != "")] | unique
' "$ISSUE_REGISTRY" 2>/dev/null || echo '[]')

TARGET_COUNT=$(jq_int 'length' <<< "$TARGET_FILES")

if [ "$TARGET_COUNT" -gt 0 ]; then
  # Mock check: file đã tồn tại VÀ issue có intent="create" → collision
  COLLISIONS='[]'
  while IFS= read -r f; do
    f=$(printf '%s' "$f" | tr -d '\r')
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
      # File exists — check if any issue has intent=create cho file này
      HAS_CREATE=$(jq_int -c --arg f "$f" '
        [.issues[] | select((.files_target // [])[] == $f and (.fix_intent // "edit") == "create")] | length
      ' "$ISSUE_REGISTRY" 2>/dev/null || echo 0)
      if [ "$HAS_CREATE" -gt 0 ]; then
        COLLISIONS=$(jq -c --arg f "$f" '. += [$f]' <<< "$COLLISIONS")
      fi
    fi
  done < <(jq -r '.[]' <<< "$TARGET_FILES")

  COLLISION_COUNT=$(jq_int 'length' <<< "$COLLISIONS")
  if [ "$COLLISION_COUNT" -gt 0 ]; then
    COLLISION_STATUS="failed"
    COLLISION_DETAILS="$COLLISION_COUNT file(s) have create-intent but already exist — risk silent overwrite (CORE-020)"
    COLLISION_FILES="$COLLISIONS"
  fi
fi

CHECK1=$(jq -nc \
  --arg status "$COLLISION_STATUS" \
  --arg details "$COLLISION_DETAILS" \
  --argjson files "$COLLISION_FILES" \
  '{name: "code_collision_search", status: $status, details: $details, files: $files}')

# ============================================================
# CHECK 2 — registry_xref
# All REQ-IDs/FEAT-IDs in issue-registry phải tồn tại trong req-registry.json.
# ============================================================
XREF_STATUS="passed"
XREF_DETAILS="All REQ-IDs/FEAT-IDs exist in req-registry.json"
ORPHAN_REFS='[]'

if [ -s "$REQ_REGISTRY" ]; then
  # Lấy REQ-IDs/FEAT-IDs from issue-registry
  ISSUE_REQ_IDS=$(jq -c '
    [.issues[] | (.req_id // null), (.feat_id // null)] | map(select(. != null and . != "")) | unique
  ' "$ISSUE_REGISTRY" 2>/dev/null || echo '[]')

  ISSUE_REF_COUNT=$(jq_int 'length' <<< "$ISSUE_REQ_IDS")

  if [ "$ISSUE_REF_COUNT" -gt 0 ]; then
    # Lấy REQ-IDs + FEAT-IDs from req-registry
    REGISTRY_IDS=$(jq -c '
      [
        (.requirements // [])[] | (.id // .req_id // null),
        (.features // [])[] | (.id // .feat_id // null)
      ] | map(select(. != null and . != "")) | unique
    ' "$REQ_REGISTRY" 2>/dev/null || echo '[]')

    # Find orphans (in issue-registry but not in req-registry)
    ORPHAN_REFS=$(jq -c \
      --argjson issue_ids "$ISSUE_REQ_IDS" \
      --argjson reg_ids "$REGISTRY_IDS" \
      'null | $issue_ids - $reg_ids' 2>/dev/null || echo '[]')

    ORPHAN_COUNT=$(jq_int 'length' <<< "$ORPHAN_REFS")
    if [ "$ORPHAN_COUNT" -gt 0 ]; then
      XREF_STATUS="failed"
      XREF_DETAILS="$ORPHAN_COUNT REQ-ID/FEAT-ID(s) trong issue-registry KHÔNG có trong req-registry.json (referential integrity violation)"
    fi
  fi
else
  XREF_STATUS="warning"
  XREF_DETAILS="req-registry.json không tồn tại — skip xref check (project chưa có docs phase 1+)"
fi

CHECK2=$(jq -nc \
  --arg status "$XREF_STATUS" \
  --arg details "$XREF_DETAILS" \
  --argjson orphans "$ORPHAN_REFS" \
  '{name: "registry_xref", status: $status, details: $details, orphan_refs: $orphans}')

# ============================================================
# CHECK 3 — uncommitted_changes_check
# Git status trong target scope. Warning nếu có files chưa commit.
# Skip nếu --skip-uncommitted-check hoặc không phải git repo.
# ============================================================
UNCOMMITTED_STATUS="passed"
UNCOMMITTED_DETAILS="No uncommitted changes in target scope"
UNCOMMITTED_FILES='[]'

if [ "$SKIP_UNCOMMITTED" = "true" ]; then
  UNCOMMITTED_STATUS="passed"
  UNCOMMITTED_DETAILS="Skipped per --skip-uncommitted-check"
elif ! git rev-parse --git-dir > /dev/null 2>&1; then
  UNCOMMITTED_STATUS="passed"
  UNCOMMITTED_DETAILS="Not a git repository — skip uncommitted check"
else
  # Get uncommitted files (modified + untracked, excluding .mc-data/work/)
  GIT_STATUS=$(git status --porcelain 2>/dev/null | grep -v '^?? .mc-data/work/' | awk '{print $2}' | head -50)

  if [ -n "$GIT_STATUS" ]; then
    # Cross-reference với target_files (from CHECK 1)
    UNCOMMITTED_IN_SCOPE='[]'
    if [ "$TARGET_COUNT" -gt 0 ]; then
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        # Check if this file is in target scope
        IN_SCOPE=$(jq_int -c --arg f "$f" '
          [. | .[] | select(. == $f)] | length
        ' <<< "$TARGET_FILES" 2>/dev/null || echo 0)
        if [ "$IN_SCOPE" -gt 0 ]; then
          UNCOMMITTED_IN_SCOPE=$(jq -c --arg f "$f" '. += [$f]' <<< "$UNCOMMITTED_IN_SCOPE")
        fi
      done <<< "$GIT_STATUS"
    fi

    SCOPE_COUNT=$(jq_int 'length' <<< "$UNCOMMITTED_IN_SCOPE")
    TOTAL_UNCOMMITTED=$(echo "$GIT_STATUS" | wc -l | tr -d ' ')

    if [ "$SCOPE_COUNT" -gt 0 ]; then
      UNCOMMITTED_STATUS="warning"
      UNCOMMITTED_DETAILS="$SCOPE_COUNT file(s) trong target scope có uncommitted changes — recommend commit trước fix"
      UNCOMMITTED_FILES="$UNCOMMITTED_IN_SCOPE"
    elif [ "$TOTAL_UNCOMMITTED" -gt 0 ]; then
      UNCOMMITTED_STATUS="passed"
      UNCOMMITTED_DETAILS="$TOTAL_UNCOMMITTED file(s) uncommitted nhưng KHÔNG trong target scope"
    fi
  fi
fi

CHECK3=$(jq -nc \
  --arg status "$UNCOMMITTED_STATUS" \
  --arg details "$UNCOMMITTED_DETAILS" \
  --argjson files "$UNCOMMITTED_FILES" \
  '{name: "uncommitted_changes_check", status: $status, details: $details, files: $files}')

# ============================================================
# CHECK 4 — deprecated_modules_filter
# Issues KHÔNG được touch DEPRECATED modules (CORE-022).
# ============================================================
DEPRECATED_STATUS="passed"
DEPRECATED_DETAILS="No issues touch DEPRECATED modules"
DEPRECATED_HITS='[]'

if [ -s "$LEGACY_DECISIONS" ]; then
  DEPRECATED_MODULES=$(jq -c '
    [.modules[]? | select(.action == "DEPRECATE") | .name] // []
  ' "$LEGACY_DECISIONS" 2>/dev/null || echo '[]')

  DEP_COUNT=$(jq_int 'length' <<< "$DEPRECATED_MODULES")

  if [ "$DEP_COUNT" -gt 0 ]; then
    # Find issues touching deprecated modules (via module field hoặc files_target path)
    DEPRECATED_HITS=$(jq -c \
      --argjson dep_mods "$DEPRECATED_MODULES" \
      '
        [
          .issues[] |
          select(
            (.module // null) as $m |
            ($m != null and ($dep_mods | index($m)))
            or
            ((.files_target // [])[] | tostring | test("/(\($dep_mods | join("|")))/"; "i"))
          ) |
          {issue_id: (.id // .issue_id), module: (.module // null), files: (.files_target // [])}
        ]
      ' "$ISSUE_REGISTRY" 2>/dev/null || echo '[]')

    HIT_COUNT=$(jq_int 'length' <<< "$DEPRECATED_HITS")
    if [ "$HIT_COUNT" -gt 0 ]; then
      DEPRECATED_STATUS="failed"
      DEPRECATED_DETAILS="$HIT_COUNT issue(s) touch DEPRECATED module(s) — vi phạm CORE-022, phải resolve trước fix"
    fi
  fi
else
  DEPRECATED_STATUS="passed"
  DEPRECATED_DETAILS="legacy-decisions.json không tồn tại — không có DEPRECATED modules cần filter"
fi

CHECK4=$(jq -nc \
  --arg status "$DEPRECATED_STATUS" \
  --arg details "$DEPRECATED_DETAILS" \
  --argjson hits "$DEPRECATED_HITS" \
  '{name: "deprecated_modules_filter", status: $status, details: $details, hits: $hits}')

# ============================================================
# AGGREGATE blockers + warnings
# ============================================================
BLOCKERS='[]'
WARNINGS='[]'

# Collect blockers (status=failed)
for check in "$CHECK1" "$CHECK2" "$CHECK3" "$CHECK4"; do
  STATUS=$(jq -r '.status' <<< "$check")
  NAME=$(jq -r '.name' <<< "$check")
  DETAILS=$(jq -r '.details' <<< "$check")
  if [ "$STATUS" = "failed" ]; then
    BLOCKERS=$(jq -c --arg n "$NAME" --arg d "$DETAILS" '. += [{check: $n, detail: $d}]' <<< "$BLOCKERS")
  elif [ "$STATUS" = "warning" ]; then
    WARNINGS=$(jq -c --arg d "$DETAILS" '. += [$d]' <<< "$WARNINGS")
  fi
done

BLOCKER_COUNT=$(jq_int 'length' <<< "$BLOCKERS")
WARNING_COUNT=$(jq_int 'length' <<< "$WARNINGS")

if [ "$BLOCKER_COUNT" -gt 0 ]; then
  GATES_PASSED=false
  CDG_REQUIRED=true
else
  GATES_PASSED=true
  CDG_REQUIRED=false
fi

# ============================================================
# ASSEMBLE final JSON
# ============================================================
RAN_AT=$(iso_now)

FINAL_JSON=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg ran "$RAN_AT" \
  --argjson gates "$GATES_PASSED" \
  --argjson cdg "$CDG_REQUIRED" \
  --argjson c1 "$CHECK1" --argjson c2 "$CHECK2" \
  --argjson c3 "$CHECK3" --argjson c4 "$CHECK4" \
  --argjson blockers "$BLOCKERS" \
  --argjson warnings "$WARNINGS" \
  '{
    "$schema": "wf-fix-safety-check-v1",
    session_id: $sid,
    ran_at: $ran,
    gates_passed: $gates,
    checks: [$c1, $c2, $c3, $c4],
    blockers: $blockers,
    warnings: $warnings,
    cdg_required: $cdg
  }')

# ============================================================
# WRITE atomic + validate
# ============================================================
atomic_write_json "$OUTPUT" "$FINAL_JSON" || { echo "ERROR: atomic_write_json failed" >&2; exit 1; }

# Verify $schema
SCHEMA=$(jq -r '."$schema"' "$OUTPUT")
[ "$SCHEMA" = "wf-fix-safety-check-v1" ] || { echo "ERROR: schema mismatch in output: $SCHEMA" >&2; exit 1; }

echo "OK: safety-check.json generated → $OUTPUT" >&2
echo "    blockers=$BLOCKER_COUNT warnings=$WARNING_COUNT gates_passed=$GATES_PASSED cdg_required=$CDG_REQUIRED" >&2

if [ "$GATES_PASSED" = "false" ]; then
  echo "FAIL: Safety check blockers — see $OUTPUT" >&2
  jq '.blockers' "$OUTPUT" >&2
  exit 3
fi

exit 0
