#!/usr/bin/env bash
# =============================================================================
# generate-phase2-report.sh — Phase 2 báo cáo (CORE-028, v10.4)
# =============================================================================
# Implements Step 2.9 — Populate Phase2-report.md template với data từ
# scope-analysis.json (đã được scan-and-analyze.sh ghi).
#
# Pattern: READ template → sed populate placeholders → STRIP metadata →
# Atomic Write. Tiếng Việt ≤15 dòng (CORE-028).
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars (override values từ scope-analysis.json):
#   STATUS_PASS              (default: PASS — orchestrator set FAIL nếu POST-GATE fail)
#   STARTED_AT, COMPLETED_AT (default: $NOW)
#
# Exit codes:
#   0 — Phase2-report.md written
#   1 — Required env var missing
#   2 — Template hoặc scope-analysis.json không tồn tại
#   3 — Atomic write fail
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase2-scan/Phase2-report.md"
SCOPE_JSON="$SESSION_DIR/phase2-scan/scope-analysis.json"
TARGET="$SESSION_DIR/phase2-scan/Phase2-report.md"

[ -f "$TPL" ] || { echo "ERROR: Template missing: $TPL (CORE-031)" >&2; exit 2; }
[ -s "$SCOPE_JSON" ] || { echo "ERROR: scope-analysis.json missing — chạy scan-and-analyze.sh trước" >&2; exit 2; }

mkdir -p "$(dirname "$TARGET")"

# ── Read values from scope-analysis.json ─────────────────────────────────────
INTERFACE_TYPE=$(jq -r '.interface_type // "unknown"' "$SCOPE_JSON")
TOTAL_FILES=$(jq -r '.code.total_files // 0' "$SCOPE_JSON")
TOTAL_LOC=$(jq -r '.code.total_loc // 0' "$SCOPE_JSON")
DEP_LEVEL=$(jq -r '.code.dependency_level // "low"' "$SCOPE_JSON")
LANGUAGES=$(jq -r '[.code.languages[]? | "\(.language)(\(.files))"] | join(", ") // "unknown"' "$SCOPE_JSON")
[ -z "$LANGUAGES" ] && LANGUAGES="unknown"
MODULES_COUNT=$(jq -r '.code.by_module // {} | length' "$SCOPE_JSON" 2>/dev/null || echo 0)
[ "$MODULES_COUNT" = "null" ] && MODULES_COUNT=0
REQ_COUNT=$(jq -r '.docs.requirements // 0' "$SCOPE_JSON")
GITNEXUS_TASKS=$(jq -r '.ci_coverage.gitnexus_tasks | join(",") // ""' "$SCOPE_JSON")
[ -z "$GITNEXUS_TASKS" ] && GITNEXUS_TASKS="(none)"
SERENA_TASKS=$(jq -r '.ci_coverage.serena_tasks | join(",") // ""' "$SCOPE_JSON")
[ -z "$SERENA_TASKS" ] && SERENA_TASKS="(none)"
FALLBACK_COUNT=$(jq -r '.ci_coverage.fallback_count // 0' "$SCOPE_JSON")

# Total docs từ doc-inventory.json (nếu có)
DOC_JSON="$SESSION_DIR/phase2-scan/doc-inventory.json"
TOTAL_DOCS=0
if [ -s "$DOC_JSON" ]; then
  TOTAL_DOCS=$(jq -r '.total_docs // 0' "$DOC_JSON")
fi

# Detection method từ env (set bởi orchestrator) hoặc default
DETECTION_METHOD="${DETECTION_METHOD:-auto}"
# Frameworks list từ env
FRAMEWORKS="${FRAMEWORKS:-none}"
[ -z "$FRAMEWORKS" ] && FRAMEWORKS="none"

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
  -e "s|\[INTERFACE_TYPE\]|$INTERFACE_TYPE|g" \
  -e "s|\[DETECTION_METHOD\]|$DETECTION_METHOD|g" \
  -e "s|\[TOTAL_FILES\]|$TOTAL_FILES|g" \
  -e "s|\[LANGUAGES\]|$LANGUAGES|g" \
  -e "s|\[MODULES_COUNT\]|$MODULES_COUNT|g" \
  -e "s|\[FRAMEWORKS\]|$FRAMEWORKS|g" \
  -e "s|\[TOTAL_DOCS\]|$TOTAL_DOCS|g" \
  -e "s|\[REQ_COUNT\]|$REQ_COUNT|g" \
  -e "s|\[GITNEXUS_TASKS\]|$GITNEXUS_TASKS|g" \
  -e "s|\[SERENA_TASKS\]|$SERENA_TASKS|g" \
  -e "s|\[FALLBACK_COUNT\]|$FALLBACK_COUNT|g" \
  -e '/_template_notes/d' \
  -e '/_schema_notes/d' \
  "$TPL" > "$TMP" \
  && [ -s "$TMP" ]; then
  mv "$TMP" "$TARGET"
  echo "ok"
  exit 0
else
  rm -f "$TMP"
  echo "ERROR: Phase2-report.md generation fail" >&2
  exit 3
fi
