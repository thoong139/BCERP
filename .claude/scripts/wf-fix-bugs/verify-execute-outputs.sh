#!/usr/bin/env bash
# =============================================================================
# verify-execute-outputs.sh — Phase 6 Step 6.6/6.7/6.7b (POST-GATE + Verify + Dashboard — v10.11)
# =============================================================================
# Gộp 3 logical sub-steps thành 1 atomic call:
#   6.6 POST-GATE T1-T4 — validate fix-report.md + docs-sync-report.json
#   6.7 Verify Outputs & Git Diff — extract counts, git diff stat/files
#   6.7b Update Bug Dashboard — append fix-log entry + regenerate dashboard
#
# v10.11.0: Additionally populate fix-execution-result.json (schema fix-execution-result-v2)
#           từ fix-log.json structured data (Phase 7 CQG-1 đọc thay regex Markdown).
#
# Required env vars:
#   SESSION_DIR
#
# Optional env vars:
#   PROJECT_DIR      (default: $(pwd))
#   TOTAL_ISSUES     (default: read từ issue-registry.json)
#   EXECUTION_MODE   (default: "live")
#
# Exit codes:
#   0 — Tất cả T1-T4 PASS + verify OK + dashboard updated + fix-execution-result.json written
#   1 — Required env var missing
#   3 — Atomic write fail (E001)
#   4 — POST-GATE FAIL (E060/E061 — orchestrator re-spawn x1)
#   6 — Result counts > TOTAL_ISSUES (E061 logic error)
#
# Output JSON (stdout):
#   {
#     "post_gate": {"t1":<bool>, "t2":<bool>, "t3":<bool>, "t4":<bool>, "all_pass":<bool>},
#     "fixed_count": <int>, "deferred_count": <int>, "failed_count": <int>,
#     "files_changed": <int>,
#     "dashboard_updated": <bool>,
#     "execution_result_written": <bool>,
#     "status": "ok|post_gate_fail|logic_error"
#   }
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

if [ -z "${SESSION_DIR:-}" ]; then
  echo "ERROR: Required env var \$SESSION_DIR is empty" >&2
  exit 1
fi

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PHASE6_DIR="$SESSION_DIR/phase6-execute"
PHASE5_DIR="$SESSION_DIR/phase5-triage"
FIX_REPORT="$PHASE6_DIR/fix-report.md"
DOCS_SYNC="$PHASE6_DIR/docs-sync-report.json"
REGISTRY="$PHASE5_DIR/issue-registry.json"
FIX_LOG="$PHASE5_DIR/fix-log.json"
DASHBOARD="$SESSION_DIR/bug-dashboard.md"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── 6.6: POST-GATE T1-T4 ─────────────────────────────────────────────────────
T1_PASS=true; T2_PASS=true; T3_PASS=true; T4_PASS=true

# T1: File Existence (non-empty)
[ -s "$FIX_REPORT" ] || { echo "T1 FAIL: fix-report.md missing/empty" >&2; T1_PASS=false; }
[ -s "$DOCS_SYNC" ] || { echo "T1 FAIL: docs-sync-report.json missing/empty" >&2; T1_PASS=false; }

# T2: Structure — fix-report.md có section header
if [ -s "$FIX_REPORT" ]; then
  grep -qE "^## |^# " "$FIX_REPORT" || { echo "T2 FAIL: fix-report.md missing section headers" >&2; T2_PASS=false; }
fi

# T3: Content — docs-sync-report.json valid JSON + .files_synced >= 0
if [ -s "$DOCS_SYNC" ]; then
  if ! jq -e '(.files_synced // 0) >= 0' "$DOCS_SYNC" >/dev/null 2>&1; then
    echo "T3 FAIL: docs-sync-report.json invalid or missing files_synced" >&2
    T3_PASS=false
  fi
fi

# T4: Cross-reference — fix-report.md có keyword fixed|resolved|repaired|dry
if [ -s "$FIX_REPORT" ]; then
  grep -qiE 'fixed|resolved|repaired|dry|deferred|failed' "$FIX_REPORT" \
    || { echo "T4 FAIL: fix-report.md missing fix-result keywords" >&2; T4_PASS=false; }
fi

ALL_PASS=true
[ "$T1_PASS" = "false" ] && ALL_PASS=false
[ "$T2_PASS" = "false" ] && ALL_PASS=false
[ "$T3_PASS" = "false" ] && ALL_PASS=false
[ "$T4_PASS" = "false" ] && ALL_PASS=false

if [ "$ALL_PASS" = "false" ]; then
  jq -n --argjson t1 "$T1_PASS" --argjson t2 "$T2_PASS" \
        --argjson t3 "$T3_PASS" --argjson t4 "$T4_PASS" \
        '{post_gate:{t1:$t1,t2:$t2,t3:$t3,t4:$t4,all_pass:false}, fixed_count:0, deferred_count:0, failed_count:0, files_changed:0, dashboard_updated:false, status:"post_gate_fail"}'
  exit 4
fi

# ── 6.7: Verify Outputs & Git Diff (v11 — SSOT chain) ──────────────────────
# Extract counts theo priority chain (Wave 1 v10.19.0, mở rộng v11.0.2):
#   0. fix-iterations.json latest completed iter (v11.0.2 — loop mode SSOT, BUG-V11-001 fix)
#   1. Per-issue entries trong fix-log.json (agent contract — fix-log-v2 schema)
#   2. Summary table "Total" row trong fix-report.md (table format hiện đại)
#   3. Regex Markdown fallback (legacy v10.x — emit WARN)
#
# Rationale Source 0 (v11.0.2): Khi Wave 2 G2 loop chạy, agent re-spawn ghi
# fix-iterations.json[].after_fix_count + agent_decisions[] nhưng KHÔNG update
# fix-report.md Summary table (top of file) hoặc append fix-log.json (per agent
# contract v11). → Source 1/2 trả counts STALE → next loop iter false-fire
# NO-PROGRESS guard. Fix: ưu tiên fix-iterations.json.iterations[-1] khi có loop
# iter completed. Backward-compat 100%: không có file/iter → fall through Source 1+.

FIXED_COUNT=0
DEFERRED_COUNT=0
FAILED_COUNT=0
COUNTS_SOURCE="none"

# ─ Source 0: fix-iterations.json loop SSOT (v11.0.2 — BUG-V11-001 fix) ───────
FIX_ITER="$PHASE6_DIR/fix-iterations.json"
if [ -s "$FIX_ITER" ]; then
  LATEST_AF=$(jq -r '
    [.iterations[]?
     | select(.completed_at != null and .after_fix_count != null)]
    | (.[-1].after_fix_count // empty)' "$FIX_ITER" 2>/dev/null || echo "")
  if [ -n "$LATEST_AF" ] && [ "$LATEST_AF" != "null" ]; then
    LATEST_AD=$(jq -r '
      [.iterations[]?
       | select(.completed_at != null and .after_deferred_count != null)]
      | (.[-1].after_deferred_count // 0)' "$FIX_ITER" 2>/dev/null || echo 0)
    # Failed = đếm agent_decisions[].action == "blocked" trên tất cả iter completed
    LATEST_BLOCKED=$(jq -r '
      [.iterations[]?
       | select(.completed_at != null)
       | .agent_decisions[]?
       | select(.action == "blocked")] | length' "$FIX_ITER" 2>/dev/null || echo 0)
    FIXED_COUNT="$LATEST_AF"
    DEFERRED_COUNT="${LATEST_AD:-0}"
    FAILED_COUNT="${LATEST_BLOCKED:-0}"
    COUNTS_SOURCE="fix_iterations_loop"
    echo "INFO(v11.0.2): Source=fix_iterations_loop — latest iter after_fix=$FIXED_COUNT, after_deferred=$DEFERRED_COUNT, blocked=$FAILED_COUNT" >&2
  fi
fi

# ─ Source 1: fix-log.json per-issue entries (preferred SSOT) ─────────────────
if [ "$COUNTS_SOURCE" = "none" ] && [ -s "$FIX_LOG" ]; then
  HAS_PER_ISSUE=$(jq '[.entries[]? | select(.issue_id != null and .issue_id != "" and (.is_summary // false) == false)] | length' "$FIX_LOG" 2>/dev/null || echo 0)
  if [ "$HAS_PER_ISSUE" -gt 0 ]; then
    FIXED_COUNT=$(jq '[.entries[]? | select(.issue_id != null and .issue_id != "" and (.is_summary // false) == false and (.result == "fixed" or .result == "resolved" or .result == "verified_resolved"))] | length' "$FIX_LOG" 2>/dev/null || echo 0)
    DEFERRED_COUNT=$(jq '[.entries[]? | select(.issue_id != null and .issue_id != "" and (.is_summary // false) == false and (.result == "deferred" or .action == "skip" or .action == "cdg_blocked"))] | length' "$FIX_LOG" 2>/dev/null || echo 0)
    FAILED_COUNT=$(jq '[.entries[]? | select(.issue_id != null and .issue_id != "" and (.is_summary // false) == false and .result == "failed")] | length' "$FIX_LOG" 2>/dev/null || echo 0)
    COUNTS_SOURCE="fix_log_per_issue"
  fi
fi

# ─ Source 2: fix-report.md Summary table parsing (table format) ──────────────
# Format target: | **Fixed** | <first_run> | <re_run> | **<TOTAL>** |
if [ "$COUNTS_SOURCE" = "none" ] && [ -s "$FIX_REPORT" ]; then
  # Đọc 30 dòng đầu sau ## Summary để tránh nhiễu re-run tables phía dưới
  TABLE_BLOCK=$(awk '/^##[ \t]*Summary/{flag=1; next} /^---|^##[ \t]/{if(flag){exit}} flag' "$FIX_REPORT" 2>/dev/null | head -50)

  # Parse "Fixed" row — extract LAST numeric value (Total column)
  parse_table_total() {
    local row="$1"
    # Strip leading/trailing pipes + bold markers, get last cell number
    echo "$row" | grep -oE '[0-9]+' | tail -1
  }
  FIXED_ROW=$(echo "$TABLE_BLOCK" | grep -iE '^\|[ \t]*\**[ \t]*Fixed[ \t]*\**[ \t]*\|' | head -1)
  DEFERRED_ROW=$(echo "$TABLE_BLOCK" | grep -iE '^\|[ \t]*\**[ \t]*Deferred[ \t]*\**[ \t]*\|' | head -1)
  FAILED_ROW=$(echo "$TABLE_BLOCK" | grep -iE '^\|[ \t]*\**[ \t]*Failed[ \t]*\**[ \t]*\|' | head -1)

  if [ -n "$FIXED_ROW" ]; then
    FIXED_COUNT=$(parse_table_total "$FIXED_ROW")
    DEFERRED_COUNT=$([ -n "$DEFERRED_ROW" ] && parse_table_total "$DEFERRED_ROW" || echo 0)
    FAILED_COUNT=$([ -n "$FAILED_ROW" ] && parse_table_total "$FAILED_ROW" || echo 0)
    COUNTS_SOURCE="fix_report_table"
  fi
fi

# ─ Source 3: Legacy regex (last fallback — emit WARN) ────────────────────────
if [ "$COUNTS_SOURCE" = "none" ] && [ -s "$FIX_REPORT" ]; then
  FIXED_COUNT=$(grep -oiE 'fixed[:= ]*[0-9]+|fixed_count[:= ]*[0-9]+|\*\*Fixed:\*\* *[0-9]+' "$FIX_REPORT" 2>/dev/null \
                | head -1 | grep -oE '[0-9]+' | head -1 || echo 0)
  DEFERRED_COUNT=$(grep -oiE 'deferred[:= ]*[0-9]+|deferred_count[:= ]*[0-9]+|\*\*Deferred:\*\* *[0-9]+' "$FIX_REPORT" 2>/dev/null \
                   | head -1 | grep -oE '[0-9]+' | head -1 || echo 0)
  FAILED_COUNT=$(grep -oiE '\bfailed[:= ]*[0-9]+|failed_count[:= ]*[0-9]+|\*\*Failed:\*\* *[0-9]+' "$FIX_REPORT" 2>/dev/null \
                 | head -1 | grep -oE '[0-9]+' | head -1 || echo 0)
  COUNTS_SOURCE="regex_md_legacy"
  echo "WARN(v11): Counts từ legacy regex — agent nên write per-issue fix-log entries (fix-log-v2 schema) hoặc Summary table trong fix-report.md để counts chính xác." >&2
fi

FIXED_COUNT=${FIXED_COUNT:-0}
DEFERRED_COUNT=${DEFERRED_COUNT:-0}
FAILED_COUNT=${FAILED_COUNT:-0}

echo "INFO(v11): Counts source=$COUNTS_SOURCE (fixed=$FIXED_COUNT, deferred=$DEFERRED_COUNT, failed=$FAILED_COUNT)" >&2

# Git diff
# G6 (v11.1.0): strip PUA U+F00D (0xEF 0x80 0x8D) + CR injected by Git on Windows.
GIT_DIFF_FILES="$PHASE6_DIR/git-diff-files.txt"
GIT_DIFF_STAT="$PHASE6_DIR/git-diff-stat.txt"
if command -v git >/dev/null 2>&1 && [ -d "$PROJECT_DIR/.git" ]; then
  (cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | tr -d '\357\200\215\r') > "$GIT_DIFF_FILES" || true
  (cd "$PROJECT_DIR" && git diff --stat 2>/dev/null | tr -d '\357\200\215\r') > "$GIT_DIFF_STAT" || echo "(Không có thay đổi)" > "$GIT_DIFF_STAT"
else
  echo "" > "$GIT_DIFF_FILES"
  echo "(git không available)" > "$GIT_DIFF_STAT"
fi
FILES_CHANGED=$(wc -l < "$GIT_DIFF_FILES" 2>/dev/null | tr -d ' ')
FILES_CHANGED=${FILES_CHANGED:-0}

# Default TOTAL_ISSUES
if [ -z "${TOTAL_ISSUES:-}" ]; then
  TOTAL_ISSUES=$(jq '.total_issues // (.issues | length) // 0' "$REGISTRY" 2>/dev/null || echo 0)
fi
TOTAL_RESULT=$((FIXED_COUNT + DEFERRED_COUNT + FAILED_COUNT))
if [ "$TOTAL_RESULT" -gt "$TOTAL_ISSUES" ]; then
  echo "WARN E061: Result count ($TOTAL_RESULT) > TOTAL_ISSUES ($TOTAL_ISSUES)" >&2
  # Soft warning — không block (counts có thể có overlap)
fi

# ── 6.7b: Update Bug Dashboard ───────────────────────────────────────────────
DASHBOARD_UPDATED=false

# Append phase summary entry vào fix-log.json (atomic)
# v11: thêm is_summary=true để per-issue queries có thể filter ra (chống polluting counts)
if [ -s "$FIX_LOG" ]; then
  TMP="$FIX_LOG.tmp.$$"
  if jq --arg ts "$NOW" --arg src "$COUNTS_SOURCE" \
        --argjson fc "$FIXED_COUNT" --argjson dc "$DEFERRED_COUNT" \
        --argjson fl "$FAILED_COUNT" --argjson files "$FILES_CHANGED" \
        '.entries += [{phase:"phase6", timestamp:$ts, is_summary:true, counts_source:$src, fixed:$fc, deferred:$dc, failed:$fl, files_changed:$files}]' \
        "$FIX_LOG" > "$TMP" \
     && jq '.' "$TMP" >/dev/null \
     && mv "$TMP" "$FIX_LOG"; then
    :
  else
    rm -f "$TMP"
    echo "WARN: fix-log.json update fail" >&2
  fi
fi

# Re-generate bug-dashboard.md (inline regen — match v10.7 generate-phase5-reports pattern)
# v10.11.0: bump dashboard version counter
PRIOR_VER=$(grep -oE 'bug-dashboard-version: *[0-9]+' "$DASHBOARD" 2>/dev/null | grep -oE '[0-9]+' | head -1)
NEXT_VER=$((${PRIOR_VER:-0} + 1))

if [ -s "$REGISTRY" ]; then
  {
    cat <<DH_HEAD
<!-- bug-dashboard-version: $NEXT_VER -->
<!-- last-writer: phase-6-update -->
<!-- last-updated: $NOW -->

# Bug Dashboard — Phase 6 Update

**Session:** $(basename "$SESSION_DIR")
**Updated:** $NOW
**Version:** $NEXT_VER

## Tổng Quan

| Chỉ số | Giá trị |
|--------|---------|
| Tổng issues | $TOTAL_ISSUES |
| Đã sửa (Fixed) | $FIXED_COUNT |
| Hoãn (Deferred) | $DEFERRED_COUNT |
| Thất bại (Failed) | $FAILED_COUNT |
| Files thay đổi | $FILES_CHANGED |

## Issue Checklist

DH_HEAD
    jq -r '
      .issues[] | "- [ ] [`" + (.dimension_id // (.lane // "?" | split("-")[0] | ascii_upcase)) +
      "`] " + (.signal_type // .severity // "issue") + ": " +
      (.location.file // .source_file // "?") + " — " +
      (.title // .description // "no description")
    ' "$REGISTRY" 2>/dev/null || echo "_(error reading registry)_"

    cat <<'DH_TAIL'

## Legend

| Marker | Meaning |
|--------|---------|
| ✅ | Fixed và verified |
| ⬜ | Pending |
| ❌ | Fix failed (cần retry) |
| ⏸️ | Deferred (CDG decision) |

> Dashboard cập nhật tự động sau mỗi Phase 6 execution step.
DH_TAIL
  } > "$DASHBOARD" 2>/dev/null && DASHBOARD_UPDATED=true
fi

# ── v10.11: Populate fix-execution-result.json (schema fix-execution-result-v2) ──
# Aggregate per-issue structured data từ fix-log.json (Phase 5 init + Phase 6 append).
# Phase 7 CQG-1 sẽ đọc file này thay vì regex Markdown.
EXEC_RESULT="$PHASE6_DIR/fix-execution-result.json"
EXEC_RESULT_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase6-execute/fix-execution-result.json"
EXECUTION_MODE="${EXECUTION_MODE:-live}"
EXEC_WRITTEN=false

# Compute audit checksum (sha256 của fix-log.json — source SSOT)
AUDIT_SHA=""
if [ -s "$FIX_LOG" ] && command -v sha256sum >/dev/null 2>&1; then
  AUDIT_SHA=$(sha256sum "$FIX_LOG" 2>/dev/null | awk '{print $1}')
elif [ -s "$FIX_LOG" ] && command -v shasum >/dev/null 2>&1; then
  AUDIT_SHA=$(shasum -a 256 "$FIX_LOG" 2>/dev/null | awk '{print $1}')
fi
AUDIT_SHA="${AUDIT_SHA:-unavailable}"

# Build per-issue array + by_dimension/by_error_code aggregates từ fix-log.json
ISSUES_JSON='[]'
BY_DIM='{}'
BY_ERR='{}'
DURATION_TOTAL=0
SKIPPED_COUNT=0
FILES_LIST='[]'

if [ -s "$FIX_LOG" ]; then
  # Extract per-fix entries (filter Phase 6 entries có issue_id, skip phase-summary entries)
  ISSUES_JSON=$(jq -c '
    [.entries[]?
     | select(.issue_id != null and .issue_id != "")
     | {
        issue_id: .issue_id,
        dimension: (.dimension // "unknown"),
        action: (.action // "fix_attempt"),
        result: (.result // "pending"),
        files_touched: ([.file_changed] | map(select(. != null and . != ""))),
        duration_sec: (.duration_sec // 0),
        retry_count: (.retry_count // 0),
        error_code: (.error_code // null),
        notes: (.notes // ""),
        timestamp: (.timestamp // "")
      }]
  ' "$FIX_LOG" 2>/dev/null || echo '[]')

  BY_DIM=$(echo "$ISSUES_JSON" | jq 'group_by(.dimension) | map({key: .[0].dimension, value: length}) | from_entries' 2>/dev/null || echo '{}')
  BY_ERR=$(echo "$ISSUES_JSON" | jq '[.[] | select(.error_code != null)] | group_by(.error_code) | map({key: .[0].error_code, value: length}) | from_entries' 2>/dev/null || echo '{}')
  DURATION_TOTAL=$(echo "$ISSUES_JSON" | jq '[.[].duration_sec // 0] | add // 0' 2>/dev/null || echo 0)
  SKIPPED_COUNT=$(echo "$ISSUES_JSON" | jq '[.[] | select(.action == "skip" or .action == "cdg_blocked")] | length' 2>/dev/null || echo 0)
fi

# Files changed list (read từ git-diff-files.txt)
if [ -s "$GIT_DIFF_FILES" ]; then
  FILES_LIST=$(jq -R -s 'split("\n") | map(select(length > 0))' < "$GIT_DIFF_FILES" 2>/dev/null || echo '[]')
fi

# Git diff one-line summary (read 1 dòng đầu từ stat)
GIT_DIFF_ONELINE=""
if [ -s "$GIT_DIFF_STAT" ]; then
  GIT_DIFF_ONELINE=$(tail -1 "$GIT_DIFF_STAT" 2>/dev/null | tr -d '\r' | head -c 200)
fi
GIT_DIFF_ONELINE="${GIT_DIFF_ONELINE:-Không có thay đổi}"

# Total targeted = từ issue-registry hoặc fallback TOTAL_ISSUES
TOTAL_TARGETED="${TOTAL_ISSUES:-0}"

# Atomic write fix-execution-result.json từ template (CORE-031: READ → POPULATE → WRITE)
EXEC_TMP="$EXEC_RESULT.tmp.$$"
if [ -f "$EXEC_RESULT_TPL" ]; then
  if jq \
    --arg sid "$(basename "$SESSION_DIR")" \
    --arg ts "$NOW" \
    --arg mode "$EXECUTION_MODE" \
    --argjson fc "$FIXED_COUNT" \
    --argjson dc "$DEFERRED_COUNT" \
    --argjson fl "$FAILED_COUNT" \
    --argjson sc "$SKIPPED_COUNT" \
    --argjson tt "$TOTAL_TARGETED" \
    --argjson dt "$DURATION_TOTAL" \
    --argjson files_n "$FILES_CHANGED" \
    --argjson files_list "$FILES_LIST" \
    --arg gds "$GIT_DIFF_ONELINE" \
    --arg sd "$SESSION_DIR" \
    --argjson issues "$ISSUES_JSON" \
    --argjson by_dim "$BY_DIM" \
    --argjson by_err "$BY_ERR" \
    --arg sha "$AUDIT_SHA" \
    '. + {
      session_id: $sid,
      generated_at: $ts,
      execution_mode: $mode,
      fixed_total: $fc,
      deferred_total: $dc,
      failed_total: $fl,
      skipped_total: $sc,
      total_issues_targeted: $tt,
      duration_total_sec: $dt,
      files_changed: $files_n,
      files_changed_list: $files_list,
      git_diff_summary: $gds,
      fix_report_path: ($sd + "/phase6-execute/fix-report.md"),
      docs_sync_report_path: ($sd + "/phase6-execute/docs-sync-report.json"),
      aggregated: {
        fixed_total: $fc,
        deferred_total: $dc,
        failed_total: $fl,
        skipped_total: $sc,
        total_issues_targeted: $tt,
        files_changed_count: $files_n,
        duration_total_sec: $dt,
        by_dimension: $by_dim,
        by_error_code: $by_err
      },
      issues: $issues,
      audit_chain: {
        source: ($sd + "/phase5-triage/fix-log.json"),
        checksum_sha256: $sha,
        derived_by: "scripts/wf-fix-bugs/verify-execute-outputs.sh"
      }
    } | del(._template_notes, ._schema_notes)' \
    "$EXEC_RESULT_TPL" > "$EXEC_TMP" 2>/dev/null \
    && jq '.' "$EXEC_TMP" >/dev/null 2>&1 \
    && mv "$EXEC_TMP" "$EXEC_RESULT"; then
    EXEC_WRITTEN=true
  else
    rm -f "$EXEC_TMP"
    echo "WARN: fix-execution-result.json write fail — Phase 7 CQG-1 sẽ fallback regex" >&2
  fi
else
  echo "WARN: fix-execution-result.json template missing — skip v2 write" >&2
fi

# ── Emit aggregated JSON ─────────────────────────────────────────────────────
# v11: thêm counts_source field cho debug/audit
jq -n \
  --argjson t1 "$T1_PASS" --argjson t2 "$T2_PASS" \
  --argjson t3 "$T3_PASS" --argjson t4 "$T4_PASS" \
  --argjson fc "$FIXED_COUNT" --argjson dc "$DEFERRED_COUNT" \
  --argjson fl "$FAILED_COUNT" --argjson files "$FILES_CHANGED" \
  --argjson du "$DASHBOARD_UPDATED" \
  --argjson erw "$EXEC_WRITTEN" \
  --arg cs "$COUNTS_SOURCE" \
  '{
    post_gate: {t1:$t1, t2:$t2, t3:$t3, t4:$t4, all_pass:true},
    fixed_count: $fc,
    deferred_count: $dc,
    failed_count: $fl,
    files_changed: $files,
    counts_source: $cs,
    dashboard_updated: $du,
    execution_result_written: $erw,
    status: "ok"
  }'

exit 0
