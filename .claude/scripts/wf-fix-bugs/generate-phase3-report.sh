#!/usr/bin/env bash
# =============================================================================
# generate-phase3-report.sh — Phase 3 báo cáo (CORE-028, v10.5)
# =============================================================================
# Implements Step 3.10 — Populate Phase3-report.md template với data từ
# work-plan.json + dimension-plan.json (đã được route-and-write.sh ghi).
#
# Pattern: READ template → sed populate placeholders → STRIP metadata →
# Atomic Write. Tiếng Việt ≤15 dòng (CORE-028).
#
# Fix CORE-031 bug v10.4 đã phát hiện ở Phase 2: trước v10.5 Step 3.10 dùng
# inline heredoc thay vì template — vi phạm CORE-031. v10.5 fix bằng sed populate.
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars (override defaults từ work-plan.json):
#   STATUS_PASS              (default: PASS — orchestrator set FAIL nếu POST-GATE fail)
#   STARTED_AT, COMPLETED_AT (default: $NOW)
#   GATE_DECISION            (default: từ workload-gate.json hoặc "continue")
#   WORKLOAD_RATIO           (default: từ workload-gate.json hoặc "1.0x")
#
# Exit codes:
#   0 — Phase3-report.md written
#   1 — Required env var missing
#   2 — Template hoặc work-plan.json không tồn tại
#   3 — Atomic write fail
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase3-plan/Phase3-report.md"
WORK_JSON="$SESSION_DIR/phase3-plan/work-plan.json"
DIM_JSON="$SESSION_DIR/phase3-plan/dimension-plan.json"
GATE_JSON="$SESSION_DIR/phase3-plan/workload-gate.json"
TARGET="$SESSION_DIR/phase3-plan/Phase3-report.md"

[ -f "$TPL" ] || { echo "ERROR: Template missing: $TPL (CORE-031)" >&2; exit 2; }
[ -s "$WORK_JSON" ] || { echo "ERROR: work-plan.json missing — chạy route-and-write.sh trước" >&2; exit 2; }

mkdir -p "$(dirname "$TARGET")"

# ── Read values from work-plan.json + dimension-plan.json ────────────────────
EXECUTION_MODE=$(jq -r '.execution_mode // "inline"' "$WORK_JSON")
AGENT_COUNT=$(jq -r '.agent_count_estimate // 0' "$WORK_JSON")
WORKLOAD_COUNT=$(jq -r '.workload_count // 1' "$WORK_JSON")
ESTIMATED_ISSUES=$(jq -r '.estimated_issues // .total_estimated_issues // 0' "$WORK_JSON")
PW_MODE=$(jq -r '.playwright.mode // "none"' "$WORK_JSON")
PW_ENABLED=$(jq -r '.playwright.enabled // false' "$WORK_JSON")

# Dimensions list (compact display)
DIMENSIONS_LIST=$(jq -r '.dimensions_applied // .dimensions // [] | join(",")' "$WORK_JSON")
TOTAL_DIMS=$(jq -r '.dimensions_applied // .dimensions // [] | length' "$WORK_JSON")
[ -z "$DIMENSIONS_LIST" ] && DIMENSIONS_LIST="(none)"

# Playwright plan summary
if [ "$PW_ENABLED" = "true" ] && [ "$PW_MODE" != "none" ]; then
  PW_ORDER=$(jq -r '.playwright.order // [] | join(" → ")' "$WORK_JSON")
  [ -z "$PW_ORDER" ] && PW_ORDER="(sequential)"
  PLAYWRIGHT_PLAN_SUMMARY="$PW_MODE ($PW_ORDER)"
else
  PLAYWRIGHT_PLAN_SUMMARY="không cần"
fi

# Gate decision + ratio từ workload-gate.json (nếu có) hoặc env override
GATE_DECISION="${GATE_DECISION:-}"
WORKLOAD_RATIO="${WORKLOAD_RATIO:-}"
if [ -z "$GATE_DECISION" ] && [ -s "$GATE_JSON" ]; then
  GATE_DECISION=$(jq -r '.decision // "continue"' "$GATE_JSON")
fi
if [ -z "$WORKLOAD_RATIO" ] && [ -s "$GATE_JSON" ]; then
  WORKLOAD_RATIO=$(jq -r '.ratio_display // "1.0x"' "$GATE_JSON")
fi
[ -z "$GATE_DECISION" ] && GATE_DECISION="continue"
[ -z "$WORKLOAD_RATIO" ] && WORKLOAD_RATIO="1.0x"

# Status + timestamps
STATUS_PASS="${STATUS_PASS:-PASS}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STARTED_AT="${STARTED_AT:-$NOW}"
COMPLETED_AT="${COMPLETED_AT:-$NOW}"

# ── Populate template via sed → atomic write ─────────────────────────────────
TMP="$TARGET.tmp.$$"
if sed \
  -e "s|\[STATUS_PASS_FAIL\]|$STATUS_PASS|g" \
  -e "s|\[STARTED_AT\]|$STARTED_AT|g" \
  -e "s|\[COMPLETED_AT\]|$COMPLETED_AT|g" \
  -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
  -e "s|\[TOTAL_DIMS\]|$TOTAL_DIMS|g" \
  -e "s|\[WORKLOAD_COUNT\]|$WORKLOAD_COUNT|g" \
  -e "s|\[GATE_DECISION\]|$GATE_DECISION|g" \
  -e "s|\[WORKLOAD_RATIO\]|$WORKLOAD_RATIO|g" \
  -e "s|\[DIMENSIONS_LIST\]|$DIMENSIONS_LIST|g" \
  -e "s|\[ESTIMATED_ISSUES\]|$ESTIMATED_ISSUES|g" \
  -e "s|\[EXECUTION_MODE\]|$EXECUTION_MODE|g" \
  -e "s|\[AGENT_COUNT\]|$AGENT_COUNT|g" \
  -e "s|\[PLAYWRIGHT_PLAN_SUMMARY\]|$PLAYWRIGHT_PLAN_SUMMARY|g" \
  -e '/_template_notes/d' \
  -e '/_schema_notes/d' \
  "$TPL" > "$TMP" \
  && [ -s "$TMP" ]; then
  mv "$TMP" "$TARGET"
  echo "ok"
  exit 0
else
  rm -f "$TMP"
  echo "ERROR: Phase3-report.md generation fail" >&2
  exit 3
fi
