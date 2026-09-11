#!/usr/bin/env bash
# =============================================================================
# generate-phase7-reports.sh — Phase 7 Step 7.6/7.7/7.8/7.9 (4 reports — v10.11)
# =============================================================================
# Gộp 4 logical sub-steps thành 1 atomic call:
#   7.6 orchestrator-summary.md — CORE-028 tiếng Việt ≤40 dòng
#   7.7 fix-impact.json — Cross-skill artifact (CORE-036, schema fix-impact-v1)
#   7.8 phase-summary.md — Accumulated 7-phase summaries
#   7.9 Phase7-report.md — CORE-028 ≤15 dòng
#
# Pattern (CORE-031): READ templates → POPULATE → STRIP metadata → Atomic Write.
#
# v10.11.0: Consume orphan outputs (đã sinh nhưng chưa được consume):
#   - phase4-summary.json → per-dim breakdown trong orchestrator-summary
#   - coverage-report.json → distribution.by_severity trong orchestrator-summary
#   - process-violations.json → PI status trong phase-summary
#   - fix-execution-result.json → by_dimension trong orchestrator-summary + fix-impact
# Tất cả là OPT-IN với graceful degradation (file missing → fallback values cũ).
#
# Required env vars:
#   SESSION_DIR, SESSION_ID
#
# Optional env vars (orchestrator có thể override):
#   PROFILE             (default: standard)
#   SCOPE               (default: all)
#   NAME                (default: "")
#   E005_HEALTHY        (default: false)
#   DIMS_ARRAY          (default: "")
#   FIXED_COUNT, DEFERRED_COUNT, FAILED_COUNT (default: 0 hoặc auto)
#   CQG1_PASS_FAIL      (default: PASS — N/A nếu E005)
#   CQG1_DEVIATION      (default: 0)
#   CQG2_PASS_FAIL      (default: PASS)
#   CQG2_BROWSER        (default: N/A)
#   CQG2_INTEGRATION    (default: N/A)
#   STATUS_PASS_FAIL    (default: PASS)
#   STARTED_AT, COMPLETED_AT (default: $NOW)
#   GITNEXUS_AVAILABLE, SERENA_AVAILABLE (default: false)
#   MOBILE_MODE         (default: false)
#   INTERFACE_TYPE      (default: hybrid)
#   PROJECT_NAME        (default: $(basename $(pwd)))
#
# Exit codes:
#   0 — All 4 reports written
#   1 — Required env var missing
#   2 — Critical template missing (orchestrator-summary or Phase7-report)
#   3 — Atomic write fail (E074)
#
# Output JSON (stdout):
#   {
#     "orchestrator_summary": "<path>",
#     "fix_impact": "<path>",
#     "phase_summary": "<path>",
#     "phase7_report": "<path>",
#     "audit_chain": "<sha256>",
#     "status": "ok"
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

PROFILE="${PROFILE:-standard}"
SCOPE="${SCOPE:-all}"
NAME="${NAME:-}"
E005_HEALTHY="${E005_HEALTHY:-false}"
DIMS_ARRAY="${DIMS_ARRAY:-}"

# v11: Counts SSOT — đọc từ fix-execution-result.json (chính xác sau re-runs)
# Env vars FIXED_COUNT/DEFERRED_COUNT/FAILED_COUNT có thể stale từ Phase 6 first-run.
# Nếu fix-execution-result.json tồn tại + schema v1/v2 → OVERRIDE env vars.
FIX_EXEC_RESULT_PRELOAD="${SESSION_DIR}/phase6-execute/fix-execution-result.json"
FIXED_COUNT="${FIXED_COUNT:-0}"
DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
FAILED_COUNT="${FAILED_COUNT:-0}"

if [ -s "$FIX_EXEC_RESULT_PRELOAD" ]; then
  SSOT_SCHEMA=$(jq -r '."$schema" // ""' "$FIX_EXEC_RESULT_PRELOAD" 2>/dev/null || echo "")
  if [ "$SSOT_SCHEMA" = "fix-execution-result-v2" ] || [ "$SSOT_SCHEMA" = "fix-execution-result-v1" ]; then
    SSOT_FIXED=$(jq -r '(.aggregated.fixed_total // .fixed_total // 0) | tostring' "$FIX_EXEC_RESULT_PRELOAD" 2>/dev/null || echo "")
    SSOT_DEFERRED=$(jq -r '(.aggregated.deferred_total // .deferred_total // 0) | tostring' "$FIX_EXEC_RESULT_PRELOAD" 2>/dev/null || echo "")
    SSOT_FAILED=$(jq -r '(.aggregated.failed_total // .failed_total // 0) | tostring' "$FIX_EXEC_RESULT_PRELOAD" 2>/dev/null || echo "")
    # Override only nếu SSOT có valid numeric values
    if echo "$SSOT_FIXED" | grep -qE '^[0-9]+$'; then
      FIXED_COUNT="$SSOT_FIXED"
      echo "INFO(v11): FIXED_COUNT override từ SSOT ($SSOT_FIXED) → đảm bảo nhất quán với fix-execution-result.json" >&2
    fi
    echo "$SSOT_DEFERRED" | grep -qE '^[0-9]+$' && DEFERRED_COUNT="$SSOT_DEFERRED"
    echo "$SSOT_FAILED" | grep -qE '^[0-9]+$' && FAILED_COUNT="$SSOT_FAILED"
  fi
fi
CQG1_PASS_FAIL="${CQG1_PASS_FAIL:-PASS}"
CQG1_DEVIATION="${CQG1_DEVIATION:-0}"
CQG2_PASS_FAIL="${CQG2_PASS_FAIL:-PASS}"
CQG2_BROWSER="${CQG2_BROWSER:-N/A}"
CQG2_INTEGRATION="${CQG2_INTEGRATION:-N/A}"
STATUS_PASS_FAIL="${STATUS_PASS_FAIL:-PASS}"
GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"
MOBILE_MODE="${MOBILE_MODE:-false}"
INTERFACE_TYPE="${INTERFACE_TYPE:-hybrid}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$(pwd)")}"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STARTED_AT="${STARTED_AT:-$NOW}"
COMPLETED_AT="${COMPLETED_AT:-$NOW}"

PHASE7_DIR="$SESSION_DIR/phase7-verify"
REGISTRY="$SESSION_DIR/phase5-triage/issue-registry.json"
FIX_STATUS="$SESSION_DIR/fix-status.json"

# v10.11.0: Inputs từ orphan outputs (opt-in fast-path consumers)
PHASE4_SUMMARY="$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
COVERAGE_JSON="$SESSION_DIR/phase5-triage/coverage-report.json"
PROCESS_VIOLATIONS="$SESSION_DIR/phase5-triage/process-violations.json"
FIX_EXEC_RESULT="$SESSION_DIR/phase6-execute/fix-execution-result.json"

ORCH_TARGET="$PHASE7_DIR/orchestrator-summary.md"
FIXIMPACT_TARGET="$PHASE7_DIR/fix-impact.json"
PHSUM_TARGET="$PHASE7_DIR/phase-summary.md"
PHASE7_TARGET="$PHASE7_DIR/Phase7-report.md"

ORCH_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/orchestrator-summary.md"
FIXIMPACT_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/fix-impact.json"
PHSUM_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/phase-summary.md"
PHASE7_TPL=".claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/Phase7-report.md"

[ -f "$ORCH_TPL" ] || { echo "ERROR: orchestrator-summary template missing" >&2; exit 2; }
[ -f "$PHASE7_TPL" ] || { echo "ERROR: Phase7-report template missing" >&2; exit 2; }

mkdir -p "$PHASE7_DIR"

# ── Common metrics ───────────────────────────────────────────────────────────
TOTAL_ISSUES=0
TOTAL_SIGNALS=0
if [ -s "$REGISTRY" ]; then
  TOTAL_ISSUES=$(jq '.total_issues // (.issues | length) // 0' "$REGISTRY" 2>/dev/null || echo 0)
fi
if [ -s "$FIX_STATUS" ]; then
  TOTAL_SIGNALS=$(jq '.signals_total // 0' "$FIX_STATUS" 2>/dev/null || echo 0)
fi

DIMS_COUNT=$(echo "$DIMS_ARRAY" | wc -w | tr -d ' ')
DIMS_COUNT=${DIMS_COUNT:-0}
PHASES_COMPLETED=$(jq '[.phases | to_entries[] | select(.value.status == "completed")] | length' "$FIX_STATUS" 2>/dev/null || echo 0)

# Dims list as YAML bullets
# v10.11.0: Enrich từ phase4-summary.json (per-dim signals breakdown) + coverage-report.json + fix-execution-result.json (by_dimension fixes)
DIMS_SUMMARY=""
DIMS_SOURCE="dims_array_only"

if [ -s "$PHASE4_SUMMARY" ] && jq -e '.dimensions' "$PHASE4_SUMMARY" >/dev/null 2>&1; then
  # Read per-dim breakdown từ phase4-summary.json (machine-readable)
  # Format: - QD1 (functional-correctness): X signals (Y crit, Z high) — F fixed
  P4_DIMS=$(jq -r '.dimensions[]? | "\(.dimension_id // .id // "?")|\(.dimension_name // .name // "")|\((.signals_total // .signals // 0))|\((.by_severity.critical // 0))|\((.by_severity.high // 0))"' "$PHASE4_SUMMARY" 2>/dev/null || echo "")

  if [ -n "$P4_DIMS" ]; then
    DIMS_SOURCE="phase4_summary"
    while IFS='|' read -r dim_id dim_name sig_cnt crit hi; do
      [ -z "$dim_id" ] && continue
      # Lookup fix count cho dim này từ fix-execution-result.json (nếu có)
      fix_for_dim=0
      if [ -s "$FIX_EXEC_RESULT" ]; then
        fix_for_dim=$(jq -r --arg d "$dim_id" '(.aggregated.by_dimension[$d] // 0)' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
      fi
      DIMS_SUMMARY="${DIMS_SUMMARY}- **${dim_id}** ${dim_name:+(${dim_name})}: ${sig_cnt} tín hiệu (${crit} critical, ${hi} high) — ${fix_for_dim} sửa\n"
    done <<< "$P4_DIMS"
  fi
fi

# Fallback: DIMS_ARRAY simple bullet list
if [ -z "$DIMS_SUMMARY" ]; then
  DIMS_SUMMARY=$(echo "$DIMS_ARRAY" | tr ' ' '\n' | grep -v '^$' | sed 's/^/- /' | head -15)
fi
[ -z "$DIMS_SUMMARY" ] && DIMS_SUMMARY="- (chưa xác định)"

# v10.11.0: Severity distribution từ coverage-report.json (machine-readable)
SEV_BREAKDOWN=""
if [ -s "$COVERAGE_JSON" ] && jq -e '.distribution.by_severity' "$COVERAGE_JSON" >/dev/null 2>&1; then
  SEV_CRIT=$(jq -r '.distribution.by_severity.critical.count // 0' "$COVERAGE_JSON" 2>/dev/null || echo 0)
  SEV_HIGH=$(jq -r '.distribution.by_severity.high.count // 0' "$COVERAGE_JSON" 2>/dev/null || echo 0)
  SEV_MED=$(jq -r '.distribution.by_severity.medium.count // 0' "$COVERAGE_JSON" 2>/dev/null || echo 0)
  SEV_LOW=$(jq -r '.distribution.by_severity.low.count // 0' "$COVERAGE_JSON" 2>/dev/null || echo 0)
  SEV_BREAKDOWN="- Critical: ${SEV_CRIT} | High: ${SEV_HIGH} | Medium: ${SEV_MED} | Low: ${SEV_LOW}"
fi

# CI tools summary
CI_TOOLS_LIST=""
[ "$GITNEXUS_AVAILABLE" = "true" ] && CI_TOOLS_LIST="${CI_TOOLS_LIST}- GitNexus (code intelligence)\n"
[ "$SERENA_AVAILABLE" = "true" ] && CI_TOOLS_LIST="${CI_TOOLS_LIST}- Serena (symbol navigation)\n"
[ -z "$CI_TOOLS_LIST" ] && CI_TOOLS_LIST="- Không có CI tool nào available — dùng Grep/Glob fallback"

# Playwright summary
PLAYWRIGHT_USED="false"
PLAYWRIGHT_SUMMARY="Không sử dụng (interface_type=$INTERFACE_TYPE hoặc QD5/7/9 không active)"
if [ "$INTERFACE_TYPE" != "api-only" ] && echo "$DIMS_ARRAY" | grep -qE "QD5|QD7|QD9"; then
  PLAYWRIGHT_USED="true"
  PLAYWRIGHT_SUMMARY="Đã sử dụng Playwright cho QD5/QD7/QD9 lanes"
fi

# Session duration (placeholder — orchestrator có thể override)
SESSION_DURATION="${SESSION_DURATION:-$(($(date +%s) - $(date -d "$STARTED_AT" +%s 2>/dev/null || echo $(date +%s)))) giây}"

# ── v11: Derive PIPELINE_STATUS_ENUM + banner ────────────────────────────────
# Đọc trực tiếp từ fix-status.json sau finalize-phase7.sh chạy (Step 7.6)
PIPELINE_STATUS_ENUM="DONE"
if [ -s "$FIX_STATUS" ]; then
  PIPELINE_STATUS_ENUM=$(jq -r '.pipeline_status // "DONE"' "$FIX_STATUS" 2>/dev/null || echo "DONE")
fi

PIPELINE_STATUS_BANNER=""
case "$PIPELINE_STATUS_ENUM" in
  DONE_CLEAN)
    PIPELINE_STATUS_BANNER="✅ **Hoàn thành sạch (DONE_CLEAN)** — Tất cả issues đã được xử lý đầy đủ. Không còn deferred items."
    ;;
  DONE_WITH_DEFERRED)
    PIPELINE_STATUS_BANNER="⚠️ **Hoàn thành có deferred (DONE_WITH_DEFERRED)** — Còn **${DEFERRED_COUNT}** issues chưa fix (chính đáng: MANUAL_FIX/ESCALATE/SKIP). Xem \`fix-report.md\` để biết chi tiết và quyết định hành động tiếp theo."
    ;;
  DONE_NEEDS_FOLLOWUP)
    PIPELINE_STATUS_BANNER="🔄 **Cần follow-up (DONE_NEEDS_FOLLOWUP)** — Có items out-of-scope đã ghi vào queue \`.mc-data/work/wf-fix-bugs/_followup-queue.jsonl\`. Chạy \`/wf-fix-bugs --resume-followup\` để xử lý các items này."
    ;;
  *)
    PIPELINE_STATUS_BANNER="✓ **Hoàn thành (DONE)** — Pipeline kết thúc bình thường."
    ;;
esac

# ── v11.2.0: Build FOLLOWUP_SECTION từ _followup-queue.jsonl ─────────────────
# Filter entries: source_session == $SESSION_ID && status == "pending"
FOLLOWUP_QUEUE="${PWD}/.mc-data/work/wf-fix-bugs/_followup-queue.jsonl"
FOLLOWUP_COUNT=0
FOLLOWUP_SECTION=""

if [ -s "$FOLLOWUP_QUEUE" ]; then
  # jq stream filter trên JSONL: lọc entries match session + pending
  FU_ENTRIES_TMP="$PHASE7_DIR/.followup-entries.tmp.$$"
  jq -c --arg sid "$SESSION_ID" \
    'select((.source_session == $sid or .session_id == $sid) and .status == "pending")' \
    "$FOLLOWUP_QUEUE" 2>/dev/null > "$FU_ENTRIES_TMP" || true

  if [ -s "$FU_ENTRIES_TMP" ]; then
    FOLLOWUP_COUNT=$(wc -l < "$FU_ENTRIES_TMP" | tr -d ' ')
    FOLLOWUP_COUNT=${FOLLOWUP_COUNT:-0}

    if [ "$FOLLOWUP_COUNT" -gt 0 ]; then
      # Build markdown table
      FOLLOWUP_SECTION="Phát hiện **${FOLLOWUP_COUNT}** items cần xử lý ở scope khác:\n\n"
      FOLLOWUP_SECTION="${FOLLOWUP_SECTION}| # | Kind | Suggested Command | Priority | Items |\n"
      FOLLOWUP_SECTION="${FOLLOWUP_SECTION}|---|------|-------------------|----------|-------|\n"

      IDX=0
      while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        IDX=$((IDX + 1))
        FU_KIND=$(echo "$entry" | jq -r '.kind // "manual_review"' 2>/dev/null)
        FU_CMD=$(echo "$entry" | jq -r '.suggested_command // ""' 2>/dev/null)
        FU_PRI=$(echo "$entry" | jq -r '.priority // "high"' 2>/dev/null)
        FU_ITEMS_CNT=$(echo "$entry" | jq -r '(.items // []) | length' 2>/dev/null || echo 0)
        FOLLOWUP_SECTION="${FOLLOWUP_SECTION}| ${IDX} | ${FU_KIND} | \`${FU_CMD}\` | ${FU_PRI} | ${FU_ITEMS_CNT} items |\n"
      done < "$FU_ENTRIES_TMP"

      FOLLOWUP_SECTION="${FOLLOWUP_SECTION}\n→ Xem chi tiết queue: \`.mc-data/work/wf-fix-bugs/_followup-queue.jsonl\`"
    fi
  fi
  rm -f "$FU_ENTRIES_TMP"
fi

if [ "$FOLLOWUP_COUNT" -eq 0 ]; then
  FOLLOWUP_SECTION="_Không có follow-up suggestions._"
fi

# ── 7.6 orchestrator-summary.md (CORE-031 sed populate) ──────────────────────
# v11: Đừng replace [PIPELINE_STATUS] + [PIPELINE_STATUS_BANNER] ở đây — chờ
# pre-finalize block phía dưới quyết định enum cuối cùng rồi mới substitute.
TMP="$ORCH_TARGET.tmp.$$"
if sed \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[SESSION_DURATION\]|$SESSION_DURATION|g" \
    -e "s|\[PROJECT_NAME\]|$PROJECT_NAME|g" \
    -e "s|\[SCOPE\]|$SCOPE|g" \
    -e "s|\[PROFILE\]|$PROFILE|g" \
    -e "s|\[TOTAL_SIGNALS\]|$TOTAL_SIGNALS|g" \
    -e "s|\[TOTAL_ISSUES\]|$TOTAL_ISSUES|g" \
    -e "s|\[TOTAL_FIXED\]|$FIXED_COUNT|g" \
    -e "s|\[DIMENSIONS_COVERED\]|$DIMS_COUNT|g" \
    -e "s|\[DIMENSIONS_TOTAL\]|$DIMS_COUNT|g" \
    "$ORCH_TPL" > "$TMP" 2>/dev/null \
   && [ -s "$TMP" ]; then
  # Inject DIMS_SUMMARY + CI_TOOLS_SUMMARY + PLAYWRIGHT_SUMMARY + SEV_BREAKDOWN
  # v11: KHÔNG inject [PIPELINE_STATUS_BANNER] ở đây — chờ pre-finalize block decide enum cuối
  SEV_FALLBACK="${SEV_BREAKDOWN:-_(không có dữ liệu severity — coverage-report.json missing)_}"
  if awk -v ds="$(printf '%b' "$DIMS_SUMMARY")" -v ct="$(printf '%b' "$CI_TOOLS_LIST")" -v ps="$PLAYWRIGHT_SUMMARY" -v sb="$SEV_FALLBACK" -v fs="$(printf '%b' "$FOLLOWUP_SECTION")" '
      {
        gsub(/\[DIMENSIONS_SUMMARY\]/, ds)
        gsub(/\[CI_TOOLS_SUMMARY\]/, ct)
        gsub(/\[PLAYWRIGHT_SUMMARY\]/, ps)
        gsub(/\[SEV_BREAKDOWN\]/, sb)
        gsub(/\[FOLLOWUP_SECTION\]/, fs)
        print
      }' "$TMP" > "${TMP}.2" 2>/dev/null && [ -s "${TMP}.2" ]; then
    mv "${TMP}.2" "$ORCH_TARGET"
    rm -f "$TMP"
  else
    rm -f "${TMP}.2"
    mv "$TMP" "$ORCH_TARGET"
  fi
else
  rm -f "$TMP"
  echo "ERROR: orchestrator-summary.md write fail (E073)" >&2
  exit 3
fi

# ── 7.7 fix-impact.json (CORE-036 cross-skill artifact) ──────────────────────
# v10.10.0 fix: Pre-finalize fix-status.json TRƯỚC khi compute checksum.
# v11: Pre-finalize set pipeline_status ENUM (DONE_CLEAN/DONE_WITH_DEFERRED/DONE_NEEDS_FOLLOWUP)
#      thay vì hardcode "DONE". finalize-phase7.sh sẽ PRESERVE giá trị này.
#
# Enum decision (v11):
#   - E005_HEALTHY=true → DONE_CLEAN (N=0 issues trivially clean)
#   - Followup queue có entries cho session này → DONE_NEEDS_FOLLOWUP (Wave 3)
#   - deferred_total == 0 → DONE_CLEAN
#   - deferred_total > 0 → DONE_WITH_DEFERRED
#   - Default fallback (không data) → DONE
PIPELINE_STATUS_FINAL="DONE"
FOLLOWUP_QUEUE_PFLZ="${PWD}/.mc-data/work/wf-fix-bugs/_followup-queue.jsonl"

if [ "$E005_HEALTHY" = "true" ]; then
  PIPELINE_STATUS_FINAL="DONE_CLEAN"
elif [ -s "$FIX_EXEC_RESULT" ]; then
  DEFERRED_TOTAL_PFLZ=$(jq -r '(.aggregated.deferred_total // .deferred_total // 0)' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
  HAS_FOLLOWUP=0
  if [ -s "$FOLLOWUP_QUEUE_PFLZ" ]; then
    HAS_FOLLOWUP=$(grep -c "\"session_id\": *\"$SESSION_ID\"" "$FOLLOWUP_QUEUE_PFLZ" 2>/dev/null || true)
    HAS_FOLLOWUP=${HAS_FOLLOWUP:-0}
  fi

  if [ "$HAS_FOLLOWUP" -gt 0 ]; then
    PIPELINE_STATUS_FINAL="DONE_NEEDS_FOLLOWUP"
  elif [ "$DEFERRED_TOTAL_PFLZ" -eq 0 ]; then
    PIPELINE_STATUS_FINAL="DONE_CLEAN"
  else
    PIPELINE_STATUS_FINAL="DONE_WITH_DEFERRED"
  fi
fi

echo "INFO(v11): pre-finalize pipeline_status enum = $PIPELINE_STATUS_FINAL" >&2

# Re-derive PIPELINE_STATUS_ENUM + BANNER (vì có thể đã thay đổi từ block trên)
PIPELINE_STATUS_ENUM="$PIPELINE_STATUS_FINAL"
case "$PIPELINE_STATUS_ENUM" in
  DONE_CLEAN)
    PIPELINE_STATUS_BANNER="✅ **Hoàn thành sạch (DONE_CLEAN)** — Tất cả issues đã được xử lý đầy đủ. Không còn deferred items."
    ;;
  DONE_WITH_DEFERRED)
    PIPELINE_STATUS_BANNER="⚠️ **Hoàn thành có deferred (DONE_WITH_DEFERRED)** — Còn **${DEFERRED_COUNT}** issues chưa fix (chính đáng: MANUAL_FIX/ESCALATE/SKIP). Xem \`fix-report.md\` để biết chi tiết và quyết định hành động tiếp theo."
    ;;
  DONE_NEEDS_FOLLOWUP)
    PIPELINE_STATUS_BANNER="🔄 **Cần follow-up (DONE_NEEDS_FOLLOWUP)** — Có items out-of-scope đã ghi vào queue \`.mc-data/work/wf-fix-bugs/_followup-queue.jsonl\`. Chạy \`/wf-fix-bugs --resume-followup\` để xử lý các items này."
    ;;
  *)
    PIPELINE_STATUS_BANNER="✓ **Hoàn thành (DONE)** — Pipeline kết thúc bình thường."
    ;;
esac

# Re-write orchestrator-summary.md với banner mới (vì lần đầu có thể đã write với enum cũ)
# Implementation: simple — sed replace [PIPELINE_STATUS] + [PIPELINE_STATUS_BANNER] một lần nữa
if [ -s "$ORCH_TARGET" ]; then
  TMP_ORCH="$ORCH_TARGET.tmp.banner.$$"
  awk -v ps_enum="$PIPELINE_STATUS_ENUM" -v ps_banner="$PIPELINE_STATUS_BANNER" '
    { gsub(/\[PIPELINE_STATUS\]/, ps_enum); gsub(/\[PIPELINE_STATUS_BANNER\]/, ps_banner); print }
  ' "$ORCH_TARGET" > "$TMP_ORCH" 2>/dev/null && [ -s "$TMP_ORCH" ] && mv "$TMP_ORCH" "$ORCH_TARGET" || rm -f "$TMP_ORCH"
fi

if [ -s "$FIX_STATUS" ]; then
  TMP_FS="$FIX_STATUS.tmp.preflz.$$"
  if jq --arg ts "$NOW" --arg ps "$PIPELINE_STATUS_FINAL" \
       '.pipeline_status = $ps
        | .phases.phase7.status = "completed"
        | .phases.phase7.completed_at = $ts
        | .updated_at = $ts' \
       "$FIX_STATUS" > "$TMP_FS" \
     && jq '.' "$TMP_FS" >/dev/null 2>&1; then
    mv "$TMP_FS" "$FIX_STATUS"
  else
    rm -f "$TMP_FS"
    echo "WARN: pre-finalize fix-status fail — checksum may not match post-Step-7.6 state" >&2
  fi
fi

AUDIT_CHAIN=""
if command -v sha256sum >/dev/null 2>&1 && [ -s "$FIX_STATUS" ]; then
  AUDIT_CHAIN=$(sha256sum "$FIX_STATUS" | cut -d' ' -f1)
fi
[ -z "$AUDIT_CHAIN" ] && AUDIT_CHAIN="0000000000000000000000000000000000000000000000000000000000000000"

# Build DIMS_LIST as JSON array
DIMS_LIST_JSON=$(echo "$DIMS_ARRAY" | tr ' ' '\n' | grep -v '^$' | jq -R -s 'split("\n") | map(select(length>0))' 2>/dev/null || echo '[]')

PIPELINE_VERSION="10.9.0"
DURATION_SECONDS=$(($(date +%s) - $(date -d "$STARTED_AT" +%s 2>/dev/null || echo $(date +%s))))

TMP="$FIXIMPACT_TARGET.tmp.$$"

# v10.11.0: by_dimension từ fix-execution-result.json (orphan output đã được consume)
BY_DIM_JSON='{}'
if [ -s "$FIX_EXEC_RESULT" ]; then
  BY_DIM_JSON=$(jq -c '(.aggregated.by_dimension // {})' "$FIX_EXEC_RESULT" 2>/dev/null || echo '{}')
fi

# v10.11.0: process_integrity từ process-violations.json (orphan output đã được consume)
PI_PASS_JSON=true
PI_TOTAL_JSON=0
PI_CRIT_JSON=0
if [ -s "$PROCESS_VIOLATIONS" ]; then
  PI_PASS_JSON=$(jq -r '.integrity_pass // true' "$PROCESS_VIOLATIONS" 2>/dev/null || echo true)
  PI_TOTAL_JSON=$(jq -r '.total_violations // 0' "$PROCESS_VIOLATIONS" 2>/dev/null || echo 0)
  PI_CRIT_JSON=$(jq -r '.critical_count // 0' "$PROCESS_VIOLATIONS" 2>/dev/null || echo 0)
fi

if [ -f "$FIXIMPACT_TPL" ]; then
  # Read template + populate via jq
  if jq \
      --arg sid "$SESSION_ID" \
      --arg ts "$NOW" \
      --arg pv "$PIPELINE_VERSION" \
      --arg sc "$SCOPE" \
      --arg nm "$NAME" \
      --arg pr "$PROFILE" \
      --argjson dims "$DIMS_LIST_JSON" \
      --argjson fc "$FIXED_COUNT" \
      --argjson ti "$TOTAL_ISSUES" \
      --argjson tsig "$TOTAL_SIGNALS" \
      --argjson dur "$DURATION_SECONDS" \
      --argjson gn "$GITNEXUS_AVAILABLE" \
      --argjson sr "$SERENA_AVAILABLE" \
      --argjson pwu "$PLAYWRIGHT_USED" \
      --arg ac "$AUDIT_CHAIN" \
      --argjson pc "$PHASES_COMPLETED" \
      --argjson by_dim "$BY_DIM_JSON" \
      --argjson pi_pass "$PI_PASS_JSON" \
      --argjson pi_total "$PI_TOTAL_JSON" \
      --argjson pi_crit "$PI_CRIT_JSON" \
      '.session_id = $sid
       | .generated_at = $ts
       | .pipeline_version = $pv
       | .scope = $sc
       | .name = $nm
       | .profile = $pr
       | .dimensions_run = $dims
       | .fixed_count = $fc
       | .issues_found = $ti
       | .signals_found = $tsig
       | .duration_seconds = $dur
       | .ci_tools_used.gitnexus = $gn
       | .ci_tools_used.serena = $sr
       | .playwright_used = $pwu
       | .by_dimension = $by_dim
       | .process_integrity = {pass: $pi_pass, total_violations: $pi_total, critical_count: $pi_crit}
       | .audit_chain.checksum = $ac
       | .audit_chain.phases_completed = $pc
       | del(._template_notes)' \
      "$FIXIMPACT_TPL" > "$TMP" 2>/dev/null \
     && jq '.' "$TMP" >/dev/null 2>&1; then
    mv "$TMP" "$FIXIMPACT_TARGET"
  else
    rm -f "$TMP"
    echo "ERROR: fix-impact.json write fail (E074)" >&2
    exit 3
  fi
else
  # Inline fallback (no template)
  jq -n \
    --arg schema "fix-impact-v1" \
    --arg sid "$SESSION_ID" --arg ts "$NOW" --arg pv "$PIPELINE_VERSION" \
    --arg sc "$SCOPE" --arg pr "$PROFILE" \
    --argjson dims "$DIMS_LIST_JSON" \
    --argjson fc "$FIXED_COUNT" --argjson ti "$TOTAL_ISSUES" --argjson tsig "$TOTAL_SIGNALS" \
    --argjson dur "$DURATION_SECONDS" \
    --argjson gn "$GITNEXUS_AVAILABLE" --argjson sr "$SERENA_AVAILABLE" \
    --argjson pwu "$PLAYWRIGHT_USED" --arg ac "$AUDIT_CHAIN" --argjson pc "$PHASES_COMPLETED" \
    '{
      "$schema": $schema, session_id: $sid, generated_at: $ts, pipeline_version: $pv,
      status: "complete", scope: $sc, profile: $pr,
      dimensions_run: $dims, fixed_count: $fc, issues_found: $ti, signals_found: $tsig,
      duration_seconds: $dur,
      ci_tools_used: {gitnexus: $gn, serena: $sr},
      playwright_used: $pwu, mobile_devices: [],
      audit_chain: {source: "$SESSION_DIR/fix-status.json", checksum: $ac, phases_completed: $pc}
    }' > "$FIXIMPACT_TARGET"
fi

# ── 7.8 phase-summary.md ─────────────────────────────────────────────────────
# v10.11.0: thêm PI section từ process-violations.json (Phase 5 output) — orphan trước v10.11.
PI_STATUS_LINE=""
if [ -s "$PROCESS_VIOLATIONS" ]; then
  PI_PASS=$(jq -r '.integrity_pass // false' "$PROCESS_VIOLATIONS" 2>/dev/null || echo "false")
  PI_CRIT=$(jq -r '.critical_count // 0' "$PROCESS_VIOLATIONS" 2>/dev/null || echo 0)
  PI_TOTAL=$(jq -r '.total_violations // 0' "$PROCESS_VIOLATIONS" 2>/dev/null || echo 0)
  if [ "$PI_PASS" = "true" ]; then
    PI_STATUS_LINE="✅ Process Integrity (PI1-PI5): PASS — không phát hiện vi phạm"
  else
    PI_STATUS_LINE="⚠️ Process Integrity: ${PI_TOTAL} vi phạm (${PI_CRIT} critical) — xem process-violations.json"
  fi
fi

{
  cat <<PHSUM_HEAD
# Phase Summary (Accumulated) — wf-fix-bugs v$PIPELINE_VERSION

> **Session:** $SESSION_ID | **Profile:** $PROFILE | **Scope:** $SCOPE $NAME
> **Hoàn thành:** $COMPLETED_AT
${PI_STATUS_LINE:+
> **Process Integrity:** $PI_STATUS_LINE}

PHSUM_HEAD

  for n in 1 2 3 4 5 6 7; do
    case "$n" in
      1) name="init"; subdir="phase1-init" ;;
      2) name="scan"; subdir="phase2-scan" ;;
      3) name="plan"; subdir="phase3-plan" ;;
      4) name="find-bugs"; subdir="phase4-find-bugs" ;;
      5) name="triage"; subdir="phase5-triage" ;;
      6) name="execute"; subdir="phase6-execute" ;;
      7) name="verify"; subdir="phase7-verify" ;;
    esac
    REPORT_FILE="$SESSION_DIR/$subdir/Phase${n}-report.md"
    echo ""
    echo "## Phase $n: ${name^}"
    if [ -s "$REPORT_FILE" ]; then
      head -8 "$REPORT_FILE" 2>/dev/null | grep -v '^---$'
    elif [ "${E005_HEALTHY:-false}" = "true" ] && [ "$n" = "6" ]; then
      # v10.10.0 fix: E005 healthy skip Phase 6 → file không tồn tại là hợp lệ
      echo "_(Phase 6 đã skip — E005 healthy path: N=0 issues phát hiện)_"
    else
      echo "_(không có dữ liệu — phase có thể đã bị interrupt hoặc skip)_"
    fi
  done

  cat <<PHSUM_TAIL

---

## Kết Quả Cuối Cùng

- **Bug Dashboard:** \`$SESSION_DIR/bug-dashboard.md\`
- **Fix Impact (cross-skill):** \`$SESSION_DIR/phase7-verify/fix-impact.json\`
- **Orchestrator Summary:** \`$SESSION_DIR/phase7-verify/orchestrator-summary.md\`
PHSUM_TAIL
} > "$PHSUM_TARGET" 2>/dev/null || { echo "ERROR: phase-summary.md write fail" >&2; exit 3; }

# ── 7.9 Phase7-report.md (CORE-028 ≤15 dòng) ────────────────────────────────
TOTAL_DURATION="${DURATION_SECONDS}s"
NEXT_ACTION_USER="/wf-verify-sync để đồng bộ"
PIPELINE_STATUS="DONE"

TMP="$PHASE7_TARGET.tmp.$$"
if sed \
    -e "s|\[STATUS_PASS_FAIL\]|$STATUS_PASS_FAIL|g" \
    -e "s|\[STARTED_AT\]|$STARTED_AT|g" \
    -e "s|\[COMPLETED_AT\]|$COMPLETED_AT|g" \
    -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[CQG1_PASS_FAIL\]|$CQG1_PASS_FAIL|g" \
    -e "s|\[CQG1_DEVIATION\]|$CQG1_DEVIATION|g" \
    -e "s|\[CQG2_PASS_FAIL\]|$CQG2_PASS_FAIL|g" \
    -e "s|\[CQG2_BROWSER\]|$CQG2_BROWSER|g" \
    -e "s|\[CQG2_INTEGRATION\]|$CQG2_INTEGRATION|g" \
    -e "s|\[PIPELINE_STATUS\]|$PIPELINE_STATUS|g" \
    -e "s|\[PHASES_COMPLETED\]|$PHASES_COMPLETED|g" \
    -e "s|\[TOTAL_DURATION\]|$TOTAL_DURATION|g" \
    -e "s|\[NEXT_ACTION_USER\]|$NEXT_ACTION_USER|g" \
    "$PHASE7_TPL" > "$TMP" 2>/dev/null \
   && [ -s "$TMP" ]; then
  mv "$TMP" "$PHASE7_TARGET"
else
  rm -f "$TMP"
  echo "ERROR: Phase7-report.md write fail (E074)" >&2
  exit 3
fi

# ── Emit summary JSON ────────────────────────────────────────────────────────
jq -n \
  --arg os "$ORCH_TARGET" --arg fi "$FIXIMPACT_TARGET" \
  --arg ps "$PHSUM_TARGET" --arg p7 "$PHASE7_TARGET" \
  --arg ac "$AUDIT_CHAIN" \
  '{
    orchestrator_summary: $os,
    fix_impact: $fi,
    phase_summary: $ps,
    phase7_report: $p7,
    audit_chain: $ac,
    status: "ok"
  }'

exit 0
