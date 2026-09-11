#!/usr/bin/env bash
# =============================================================================
# safety-check.sh — Phase 5 Step 5.10 (CORE-020 Pre-Implementation Safety Gate — v10.7)
# =============================================================================
# 4 safety checks trước Phase 6 Execute:
#   1. Collision Detection — fix-plan files có conflict với code hiện tại?
#   2. Xref Validation — REQ-IDs trong fix-plan có hợp lệ trong registry?
#   3. Uncommitted Changes — git diff phát hiện dirty working tree?
#   4. Deprecated Modules (LEGACY_MODE only) — fix-plan reference deprecated?
#
# Output: $SESSION_DIR/phase5-triage/safety-check.json (schema safety-check-v1)
# Template (CORE-031): templates/phase5-triage/safety-check.json
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars:
#   PROJECT_DIR     (default: $(pwd) — for git + registry path)
#   LEGACY_MODE     (default: false)
#
# Exit codes:
#   0 — Safety PASS (zero blockers)
#   1 — Required env var missing
#   2 — Template missing
#   3 — Atomic write fail
#   5 — Blockers detected (E055 — orchestrator render CDG)
#
# Output JSON (stdout):
#   {
#     "all_pass": <bool>,
#     "blockers_count": <int>,
#     "collision_count": <int>,
#     "xref_warnings": <int>,
#     "uncommitted_files": <int>,
#     "deprecated_refs": <int>,
#     "status": "ok|blockers|warn"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
LEGACY_MODE="${LEGACY_MODE:-false}"

SG_DIR="$SESSION_DIR/phase5-triage"
FIX_PLAN="$SG_DIR/fix-plan.md"
TARGET="$SG_DIR/safety-check.json"
TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/safety-check.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -f "$TPL" ] || { echo "ERROR: Template missing: $TPL (CORE-031)" >&2; exit 2; }
[ -s "$FIX_PLAN" ] || { echo "ERROR: fix-plan.md missing" >&2; exit 1; }

mkdir -p "$SG_DIR"

# Initialize counters
COLLISION_COUNT=0
COLLISION_DETAILS=""
XREF_WARNINGS=0
XREF_DETAILS=""
UNCOMMITTED_FILES=0
UNCOMMITTED_DETAILS=""
DEPRECATED_REFS=0
DEPRECATED_DETAILS=""
BLOCKERS_JSON='[]'

# ── 1. Collision Detection ───────────────────────────────────────────────────
# Extract file references từ fix-plan (backtick-wrapped)
COLLISION_FILES=""
while IFS= read -r line; do
  for f in $(echo "$line" | grep -oP '`[^`]+\.[a-zA-Z0-9]+`' 2>/dev/null | tr -d '`'); do
    if [ -f "$PROJECT_DIR/$f" ] || [ -f "$f" ]; then
      COLLISION_COUNT=$((COLLISION_COUNT + 1))
      COLLISION_FILES="$COLLISION_FILES $f"
    fi
  done
done < "$FIX_PLAN"
COLLISION_DETAILS=$(echo "$COLLISION_FILES" | tr ' ' '\n' | sort -u | grep -v '^$' | head -20 | tr '\n' ',' | sed 's/,$//')

# ── 2. Xref Validation (REQ-ID trong fix-plan có trong registry?) ────────────
REGISTRY="$PROJECT_DIR/.mc-data/docs/_meta/req-registry.json"
if [ -f "$REGISTRY" ]; then
  for rid in $(grep -oE 'REQ-[A-Z]+-[A-Z0-9]+-?[0-9]*' "$FIX_PLAN" 2>/dev/null | sort -u); do
    if ! grep -q "\"$rid\"" "$REGISTRY" 2>/dev/null; then
      XREF_WARNINGS=$((XREF_WARNINGS + 1))
      XREF_DETAILS="$XREF_DETAILS $rid"
    fi
  done
fi
XREF_DETAILS=$(echo "$XREF_DETAILS" | sed 's/^ //;s/ /,/g' | cut -c1-200)

# ── 3. Uncommitted Changes ───────────────────────────────────────────────────
# G6 (v11.1.0): strip PUA U+F00D (0xEF 0x80 0x8D) + CR injected by Git on Windows.
# Git Bash with Nerd Fonts hoặc core.quotepath=true có thể chèn byte rác này vào output.
if command -v git >/dev/null 2>&1 && [ -d "$PROJECT_DIR/.git" ]; then
  UNCOMMITTED_FILES=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | tr -d '\357\200\215\r' | wc -l | tr -d ' ')
  UNCOMMITTED_FILES=${UNCOMMITTED_FILES:-0}
  if [ "$UNCOMMITTED_FILES" -gt 0 ]; then
    UNCOMMITTED_DETAILS=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | tr -d '\357\200\215\r' | head -10 | tr '\n' ',' | sed 's/,$//')
  fi
fi

# ── 4. Deprecated Modules (LEGACY_MODE only — CORE-022) ──────────────────────
LEGACY_DECISIONS="$PROJECT_DIR/.mc-data/docs/phase0-brainstorm/legacy-decisions.json"
if [ "$LEGACY_MODE" = "true" ] && [ -f "$LEGACY_DECISIONS" ]; then
  for mod in $(jq -r '(.modules // [])[] | select(.action == "DEPRECATE") | .name' \
               "$LEGACY_DECISIONS" 2>/dev/null); do
    if grep -q "$mod" "$FIX_PLAN" 2>/dev/null; then
      DEPRECATED_REFS=$((DEPRECATED_REFS + 1))
      DEPRECATED_DETAILS="$DEPRECATED_DETAILS $mod"
      BLOCKERS_JSON=$(echo "$BLOCKERS_JSON" | jq --arg m "$mod" \
        '. + [{type: "deprecated_module", name: $m, severity: "high"}]')
    fi
  done
fi
DEPRECATED_DETAILS=$(echo "$DEPRECATED_DETAILS" | sed 's/^ //;s/ /,/g')

# ── Determine pass status per check ──────────────────────────────────────────
# collision_detection: PASS = không có file collision (zero = PASS)
COLLISION_PASS=true
[ "$COLLISION_COUNT" -gt 0 ] && COLLISION_PASS=false

# xref_validation: PASS = không có REQ-ID warning
XREF_PASS=true
[ "$XREF_WARNINGS" -gt 0 ] && XREF_PASS=false

# uncommitted_changes: WARN nếu > 0, không phải blocker
UNCOMMITTED_PASS=true
[ "$UNCOMMITTED_FILES" -gt 0 ] && UNCOMMITTED_PASS=false

# deprecated_modules: BLOCKER nếu reference (CORE-022)
DEPRECATED_PASS=true
[ "$DEPRECATED_REFS" -gt 0 ] && DEPRECATED_PASS=false

# Blocker count = chỉ deprecated_modules (CORE-022 hard rule)
BLOCKERS_COUNT=$DEPRECATED_REFS

ALL_PASS=true
[ "$BLOCKERS_COUNT" -gt 0 ] && ALL_PASS=false

# ── Build safety-check.json from template (CORE-031) ─────────────────────────
TMP="$TARGET.tmp.$$"
jq \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --argjson all "$ALL_PASS" \
  --argjson blockers "$BLOCKERS_JSON" \
  --argjson colp "$COLLISION_PASS" --arg cold "$COLLISION_DETAILS" \
  --argjson xrp "$XREF_PASS" --arg xrd "$XREF_DETAILS" \
  --argjson ucp "$UNCOMMITTED_PASS" --arg ucd "$UNCOMMITTED_DETAILS" \
  --argjson dpp "$DEPRECATED_PASS" --arg dpd "$DEPRECATED_DETAILS" \
  '.session_id = $sid
   | .generated_at = $ts
   | .all_pass = $all
   | .blockers = $blockers
   | .checks.collision_detection = {pass: $colp, details: $cold}
   | .checks.xref_validation = {pass: $xrp, details: $xrd}
   | .checks.uncommitted_changes = {pass: $ucp, details: $ucd}
   | .checks.deprecated_modules = {pass: $dpp, details: $dpd}
   | del(._template_notes)' \
  "$TPL" > "$TMP" 2>/dev/null

if [ -s "$TMP" ] && jq '.' "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$TARGET"
else
  rm -f "$TMP"
  echo "ERROR: Atomic write safety-check.json fail (E035)" >&2
  exit 3
fi

# ── Emit summary JSON ────────────────────────────────────────────────────────
STATUS="ok"
EXIT_CODE=0
if [ "$BLOCKERS_COUNT" -gt 0 ]; then
  STATUS="blockers"
  EXIT_CODE=5
elif [ "$UNCOMMITTED_FILES" -gt 0 ] || [ "$XREF_WARNINGS" -gt 0 ] || [ "$COLLISION_COUNT" -gt 0 ]; then
  STATUS="warn"
fi

jq -n \
  --argjson ap "$ALL_PASS" \
  --argjson bc "$BLOCKERS_COUNT" \
  --argjson cc "$COLLISION_COUNT" \
  --argjson xw "$XREF_WARNINGS" \
  --argjson uf "$UNCOMMITTED_FILES" \
  --argjson dr "$DEPRECATED_REFS" \
  --arg st "$STATUS" \
  '{
    all_pass: $ap,
    blockers_count: $bc,
    collision_count: $cc,
    xref_warnings: $xw,
    uncommitted_files: $uf,
    deprecated_refs: $dr,
    status: $st
  }'

exit "$EXIT_CODE"
