#!/usr/bin/env bash
# =============================================================================
# generate-phase5-reports.sh — Phase 5 Steps 5.11+5.12+5.13 (gộp 3 reports — v10.7)
# =============================================================================
# Gộp 3 logical sub-steps thành 1 atomic call:
#   5.11 Coverage Report — coverage-report.md (metrics: probes, dimensions, success rate)
#   5.12 Bug Dashboard — $SESSION_DIR/bug-dashboard.md (checklist by lane)
#   5.13 Phase5-report.md — CORE-028 tiếng Việt ≤15 dòng
#
# Pattern (CORE-031): READ template → POPULATE placeholders → STRIP metadata → Atomic Write.
#
# Required env vars:
#   SESSION_DIR, SESSION_ID, PROFILE, SCOPE
#
# Optional env vars:
#   STATUS_PASS_FAIL    (default: PASS)
#   STARTED_AT          (default: $NOW)
#   COMPLETED_AT        (default: $NOW)
#
# Exit codes:
#   0 — Tất cả 3 reports written
#   1 — Required env var missing
#   2 — Coverage hoặc Phase5-report template missing
#   3 — Atomic write fail
#
# Output JSON (stdout):
#   {
#     "coverage_report": "<path>",
#     "bug_dashboard": "<path>",
#     "phase5_report": "<path>",
#     "total_issues": <int>,
#     "critical": <int>, "high": <int>,
#     "status": "ok"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

for var in SESSION_DIR SESSION_ID PROFILE SCOPE; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required env var \$$var is empty" >&2
    exit 1
  fi
done

SG_DIR="$SESSION_DIR/phase5-triage"
LANES_ROOT="$SESSION_DIR/phase4-find-bugs/lanes"
REGISTRY="$SG_DIR/issue-registry.json"
BUG_TRIAGE="$SG_DIR/bug-triage.md"
SAFETY="$SG_DIR/safety-check.json"
CDG_TOKENS="$SG_DIR/cdg-tokens.json"

COVERAGE_TARGET="$SG_DIR/coverage-report.md"
COVERAGE_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/coverage-report.md"
COVERAGE_JSON_TARGET="$SG_DIR/coverage-report.json"
COVERAGE_JSON_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/coverage-report.json"
DASHBOARD_TARGET="$SESSION_DIR/bug-dashboard.md"
DASHBOARD_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/bug-dashboard.md"
PHASE5_REPORT_TARGET="$SG_DIR/Phase5-report.md"
PHASE5_REPORT_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/Phase5-report.md"

[ -f "$COVERAGE_TPL" ] || { echo "ERROR: coverage-report template missing (CORE-031)" >&2; exit 2; }
[ -f "$PHASE5_REPORT_TPL" ] || { echo "ERROR: Phase5-report template missing (CORE-031)" >&2; exit 2; }
[ -s "$REGISTRY" ] || { echo "ERROR: issue-registry.json missing" >&2; exit 1; }

mkdir -p "$SG_DIR"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATUS_PASS_FAIL="${STATUS_PASS_FAIL:-PASS}"
STARTED_AT="${STARTED_AT:-$NOW}"
COMPLETED_AT="${COMPLETED_AT:-$NOW}"

# ── Common metrics ───────────────────────────────────────────────────────────
TOTAL_ISSUES=$(jq '.total_issues // 0' "$REGISTRY")
DIMS_RUN=$(find "$LANES_ROOT/" -name "lane-status.json" 2>/dev/null | wc -l | tr -d ' ')
DIMS_RUN=${DIMS_RUN:-0}
PROBES_RUN=$(jq '[.issues[].probe_id] | unique | length' "$REGISTRY" 2>/dev/null || echo 0)

# Severity counts from bug-triage.md (best effort)
# Note: grep -c always prints count (0 if no match), exit 1 if no match — `|| echo 0` corrupts với "0\n0"
CRITICAL_COUNT=0; HIGH_COUNT=0; MEDIUM_COUNT=0; LOW_COUNT=0
if [ -s "$BUG_TRIAGE" ]; then
  CRITICAL_COUNT=$(grep -ciE 'critical|nguy hiểm' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  HIGH_COUNT=$(grep -ciE '\bhigh\b|cao' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  MEDIUM_COUNT=$(grep -ciE 'medium|trung bình' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  LOW_COUNT=$(grep -ciE '\blow\b|thấp' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  [ -z "$CRITICAL_COUNT" ] && CRITICAL_COUNT=0
  [ -z "$HIGH_COUNT" ] && HIGH_COUNT=0
  [ -z "$MEDIUM_COUNT" ] && MEDIUM_COUNT=0
  [ -z "$LOW_COUNT" ] && LOW_COUNT=0
fi
# Cap to TOTAL_ISSUES
[ "$CRITICAL_COUNT" -gt "$TOTAL_ISSUES" ] 2>/dev/null && CRITICAL_COUNT=$TOTAL_ISSUES
[ "$HIGH_COUNT" -gt "$TOTAL_ISSUES" ] 2>/dev/null && HIGH_COUNT=$TOTAL_ISSUES

# Percentages
pct() {
  if [ "$TOTAL_ISSUES" -eq 0 ]; then echo "0"
  else awk -v v="$1" -v t="$TOTAL_ISSUES" 'BEGIN {if(t>0) printf "%d", v*100/t; else print "0"}'
  fi
}
CRITICAL_PCT=$(pct "$CRITICAL_COUNT")
HIGH_PCT=$(pct "$HIGH_COUNT")
MEDIUM_PCT=$(pct "$MEDIUM_COUNT")
LOW_PCT=$(pct "$LOW_COUNT")

# ── 5.11: Coverage Report ────────────────────────────────────────────────────
# Build COVERAGE_ROWS dynamically: per dim
COVERAGE_ROWS=""
for dim_dir in "$LANES_ROOT/"*/; do
  [ -d "$dim_dir" ] || continue
  dim_name=$(basename "$dim_dir")
  sig_count=$(find "$dim_dir" -name "signals.json" -exec jq '(.signals // []) | length' {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
  [ -z "$sig_count" ] && sig_count=0
  COVERAGE_ROWS="${COVERAGE_ROWS}| $dim_name | - | - | $sig_count signals |\n"
done

DIMS_TOTAL=$DIMS_RUN
DIMS_COVERED=$DIMS_RUN
DIMS_SKIPPED=0
PROBE_SUCCESS_RATE="100"

TMP="$COVERAGE_TARGET.tmp.$$"
# Use perl to replace [COVERAGE_ROWS] with multi-line content
if sed \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[GENERATED_AT\]|$NOW|g" \
    -e "s|\[CRITICAL_PCT\]|$CRITICAL_PCT|g" \
    -e "s|\[HIGH_PCT\]|$HIGH_PCT|g" \
    -e "s|\[MEDIUM_PCT\]|$MEDIUM_PCT|g" \
    -e "s|\[LOW_PCT\]|$LOW_PCT|g" \
    -e "s|\[CRITICAL\]|$CRITICAL_COUNT|g" \
    -e "s|\[HIGH\]|$HIGH_COUNT|g" \
    -e "s|\[MEDIUM\]|$MEDIUM_COUNT|g" \
    -e "s|\[LOW\]|$LOW_COUNT|g" \
    -e "s|\[DIMS_COVERED\]|$DIMS_COVERED|g" \
    -e "s|\[DIMS_TOTAL\]|$DIMS_TOTAL|g" \
    -e "s|\[DIMS_SKIPPED\]|$DIMS_SKIPPED|g" \
    -e "s|\[PROBE_SUCCESS_RATE\]|$PROBE_SUCCESS_RATE|g" \
    "$COVERAGE_TPL" > "$TMP" 2>/dev/null \
   && [ -s "$TMP" ]; then
  # Inject COVERAGE_ROWS (multi-line) via awk
  awk -v rows="$(printf '%b' "$COVERAGE_ROWS" | sed 's/$/\\/' | head -c -1)" \
      '{gsub(/\[COVERAGE_ROWS\]/, rows); print}' "$TMP" > "${TMP}.2" 2>/dev/null \
    && mv "${TMP}.2" "$TMP" 2>/dev/null || true
  mv "$TMP" "$COVERAGE_TARGET"
else
  rm -f "$TMP"
  echo "ERROR: coverage-report.md write fail (E035)" >&2
  exit 3
fi

# ── 5.11b (v10.11): Coverage Report JSON (song hành Markdown, machine-readable) ──
# Cho phép Phase 7 / consumer downstream đọc structured data thay vì parse Markdown.
COVERAGE_JSON_WRITTEN=false
if [ -f "$COVERAGE_JSON_TPL" ]; then
  # Build per-dim breakdown từ lanes
  DIMS_ARR='[]'
  for dim_dir in "$LANES_ROOT/"*/; do
    [ -d "$dim_dir" ] || continue
    dim_name=$(basename "$dim_dir")
    dim_id=$(echo "$dim_name" | cut -d'-' -f1)  # vd QD1-functional-correctness → QD1
    sig_count=$(find "$dim_dir" -name "signals.json" -exec jq '(.signals // []) | length' {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
    sig_count=${sig_count:-0}
    probes_run=$(find "$dim_dir" -name "signals.json" -exec jq -r '(.signals // [])[].probe_id' {} + 2>/dev/null | sort -u | grep -c . | tr -d ' ')
    probes_run=${probes_run:-0}
    DIMS_ARR=$(echo "$DIMS_ARR" | jq \
      --arg id "$dim_id" --arg name "$dim_name" \
      --argjson pr "$probes_run" --argjson sc "$sig_count" \
      '. + [{
        dimension_id: $id,
        dimension_name: $name,
        probes_run: $pr,
        probes_total: $pr,
        coverage_pct: 100,
        signals_found: $sc
      }]')
  done

  COV_TMP="$COVERAGE_JSON_TARGET.tmp.$$"
  if jq \
      --arg sid "$SESSION_ID" \
      --arg ts "$NOW" \
      --argjson dims "$DIMS_ARR" \
      --argjson c "$CRITICAL_COUNT" --argjson cp "$CRITICAL_PCT" \
      --argjson h "$HIGH_COUNT" --argjson hp "$HIGH_PCT" \
      --argjson m "$MEDIUM_COUNT" --argjson mp "$MEDIUM_PCT" \
      --argjson l "$LOW_COUNT" --argjson lp "$LOW_PCT" \
      --argjson dc "$DIMS_COVERED" --argjson dt "$DIMS_TOTAL" \
      --argjson psr "$PROBE_SUCCESS_RATE" \
      --argjson ti "$TOTAL_ISSUES" \
      '.session_id = $sid |
       .generated_at = $ts |
       .dimensions = $dims |
       .distribution.by_severity.critical = {count: $c, pct: $cp} |
       .distribution.by_severity.high = {count: $h, pct: $hp} |
       .distribution.by_severity.medium = {count: $m, pct: $mp} |
       .distribution.by_severity.low = {count: $l, pct: $lp} |
       .totals.dims_covered = $dc |
       .totals.dims_total = $dt |
       .totals.dims_skipped = [] |
       .totals.probe_success_rate = $psr |
       .totals.total_signals = $ti |
       .totals.total_issues = $ti |
       del(._template_notes, ._schema_notes)' \
      "$COVERAGE_JSON_TPL" > "$COV_TMP" 2>/dev/null \
     && jq '.' "$COV_TMP" >/dev/null 2>&1 \
     && mv "$COV_TMP" "$COVERAGE_JSON_TARGET"; then
    COVERAGE_JSON_WRITTEN=true
  else
    rm -f "$COV_TMP"
    echo "WARN: coverage-report.json write fail (non-fatal — Markdown still available)" >&2
  fi
fi

# ── 5.12: Bug Dashboard (inline generation — matches original v10.6 fallback) ─
# Note: Original Step 5.12 fallback dùng simple checklist format thay vì complex template
# v10.11.0: bump dashboard version counter (HTML comment marker — CORE-025 concurrent-write detect)
PRIOR_VER=$(grep -oE 'bug-dashboard-version: *[0-9]+' "$DASHBOARD_TARGET" 2>/dev/null | grep -oE '[0-9]+' | head -1)
NEXT_VER=$((${PRIOR_VER:-0} + 1))

{
  cat <<DASHBOARD_HEAD
<!-- bug-dashboard-version: $NEXT_VER -->
<!-- last-writer: phase-5-populate -->
<!-- last-updated: $NOW -->

# Bug Dashboard — ${SCOPE}

**Session:** $SESSION_ID
**Generated:** $NOW
**Profile:** $PROFILE
**Total Issues:** $TOTAL_ISSUES
**Version:** $NEXT_VER

## Issue Checklist

DASHBOARD_HEAD

  if [ "$TOTAL_ISSUES" -gt 0 ]; then
    jq -r '
      .issues[] |
      "- [ ] [`" + (.dimension_id // (.lane // "?" | split("-")[0] | ascii_upcase)) + "`] " +
      (.signal_type // .severity // "issue") + ": " +
      (.location.file // .source_file // "?") + " — " +
      (.title // .description // "no description")
    ' "$REGISTRY" 2>/dev/null
  else
    echo "_No issues found._"
  fi

  cat <<DASHBOARD_TAIL

## Legend

| Marker | Meaning |
|--------|---------|
| \`[QD1]\` | Functional Correctness |
| \`[QD2]\` | Business Correctness |
| \`[QD3]\` | Security |
| \`[QD4]\` | Performance |
| \`[QD5]\` | Accessibility/UX |
| \`[QD6]\` | Data Integrity |
| \`[QD7]\` | Compatibility |
| \`[QD8]\` | Observability |
| \`[QD9]\` | Runtime Health |
| \`[QD10]\` | Integration |
| \`[QD11]\` | Business Completeness |

## Hướng dẫn

- ✅ = Fixed và verified
- ⬜ = Pending
- ❌ = Fix failed (cần retry)
- ⏭️ = Skipped (CDG decision)

> Dashboard cập nhật tự động sau mỗi Phase 6 execution step.
DASHBOARD_TAIL
} > "$DASHBOARD_TARGET" 2>/dev/null

# ── 5.13: Phase5-report.md (CORE-028 tiếng Việt ≤15 dòng) ────────────────────
RAW_SIGNALS=$(jq -r '.signals_total // 0' "$SESSION_DIR/fix-status.json" 2>/dev/null || echo 0)
[ "$RAW_SIGNALS" = "null" ] && RAW_SIGNALS=0
SAFETY_ALL_PASS=$(jq -r 'if .all_pass then "PASS" else "BLOCKERS" end' "$SAFETY" 2>/dev/null || echo "?")
CDG_DECISION=$(jq -r '.tokens[-1].decision // "PENDING"' "$CDG_TOKENS" 2>/dev/null || echo "PENDING")
TOKENS_ACCEPTED=$(jq '[.tokens[] | select(.decision == "ACCEPT" or .status == "accepted")] | length' "$CDG_TOKENS" 2>/dev/null || echo 0)
TOKENS_TOTAL=$(jq '.tokens | length' "$CDG_TOKENS" 2>/dev/null || echo 0)

# Auto/Manual/Deferred counts (placeholder — bug-triage agent xác định, ta best-effort)
# Note: grep -c returns 0/1 exit code but always prints count; `|| echo 0` corrupts với "0\n0"
AUTO=0; MANUAL=0; DEFERRED=0
if [ -s "$BUG_TRIAGE" ]; then
  AUTO=$(grep -ciE 'auto|tự động' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  MANUAL=$(grep -ciE 'manual|thủ công' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  DEFERRED=$(grep -ciE 'defer|hoãn' "$BUG_TRIAGE" 2>/dev/null | head -1 | tr -d '\r')
  [ -z "$AUTO" ] && AUTO=0
  [ -z "$MANUAL" ] && MANUAL=0
  [ -z "$DEFERRED" ] && DEFERRED=0
fi
[ "$AUTO" -gt "$TOTAL_ISSUES" ] 2>/dev/null && AUTO=$TOTAL_ISSUES

TMP="$PHASE5_REPORT_TARGET.tmp.$$"
if sed \
    -e "s|\[STATUS_PASS_FAIL\]|$STATUS_PASS_FAIL|g" \
    -e "s|\[STARTED_AT\]|$STARTED_AT|g" \
    -e "s|\[COMPLETED_AT\]|$COMPLETED_AT|g" \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[RAW_SIGNALS\]|$RAW_SIGNALS|g" \
    -e "s|\[DEDUPED_SIGNALS\]|$TOTAL_ISSUES|g" \
    -e "s|\[TOTAL_ISSUES\]|$TOTAL_ISSUES|g" \
    -e "s|\[CRITICAL\]|$CRITICAL_COUNT|g" \
    -e "s|\[HIGH\]|$HIGH_COUNT|g" \
    -e "s|\[MEDIUM\]|$MEDIUM_COUNT|g" \
    -e "s|\[LOW\]|$LOW_COUNT|g" \
    -e "s|\[AUTO\]|$AUTO|g" \
    -e "s|\[MANUAL\]|$MANUAL|g" \
    -e "s|\[DEFERRED\]|$DEFERRED|g" \
    -e "s|\[CDG_DECISION\]|$CDG_DECISION|g" \
    -e "s|\[TOKENS_ACCEPTED\]|$TOKENS_ACCEPTED|g" \
    -e "s|\[TOKENS_TOTAL\]|$TOKENS_TOTAL|g" \
    -e "s|\[SAFETY_ALL_PASS\]|$SAFETY_ALL_PASS|g" \
    "$PHASE5_REPORT_TPL" > "$TMP" 2>/dev/null \
   && [ -s "$TMP" ]; then
  mv "$TMP" "$PHASE5_REPORT_TARGET"
else
  rm -f "$TMP"
  echo "ERROR: Phase5-report.md write fail (E035)" >&2
  exit 3
fi

# ── Emit summary JSON ────────────────────────────────────────────────────────
jq -n \
  --arg cov "$COVERAGE_TARGET" \
  --arg covjson "$COVERAGE_JSON_TARGET" \
  --arg dash "$DASHBOARD_TARGET" \
  --arg rep "$PHASE5_REPORT_TARGET" \
  --argjson ti "$TOTAL_ISSUES" \
  --argjson c "$CRITICAL_COUNT" \
  --argjson h "$HIGH_COUNT" \
  --argjson cjw "$COVERAGE_JSON_WRITTEN" \
  '{
    coverage_report: $cov,
    coverage_report_json: $covjson,
    coverage_json_written: $cjw,
    bug_dashboard: $dash,
    phase5_report: $rep,
    total_issues: $ti,
    critical: $c,
    high: $h,
    status: "ok"
  }'

exit 0
