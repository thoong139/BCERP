# Phase 7 POST-GATE + Error Reference

> **Entry condition:** Group G PASS (TodoWrite + Completion Display rendered).
> **Exit condition:** All T1-T5 checks PASS → Pipeline END. User nên chạy `/wf-verify-sync --from-fix-bugs`.
> **Next:** Pipeline END — không có Phase 8. fix-impact.json sẵn sàng làm cross-skill input (CORE-036).

## POST-GATE T1-T5 Validation

```bash
# T1 — File Existence (4 reports + dashboard)
test -s "$SESSION_DIR/phase7-verify/orchestrator-summary.md"  || echo "FAIL T1: orchestrator-summary"
test -s "$SESSION_DIR/phase7-verify/fix-impact.json"          || echo "FAIL T1: fix-impact"
test -s "$SESSION_DIR/phase7-verify/phase-summary.md"         || echo "FAIL T1: phase-summary"
test -s "$SESSION_DIR/phase7-verify/Phase7-report.md"         || echo "FAIL T1: Phase7-report"
test -s "$SESSION_DIR/bug-dashboard.md"                       || echo "FAIL T1: bug-dashboard"

# T2 — Structure (markdown headers)
grep -qE "^## " "$SESSION_DIR/phase7-verify/orchestrator-summary.md" \
  || echo "FAIL T2: orchestrator-summary missing headers"
grep -qE "^## " "$SESSION_DIR/phase7-verify/Phase7-report.md" \
  || echo "FAIL T2: Phase7-report missing headers"

# T3 — Cross-Skill Artifact (CORE-036): fix-impact.json schema + audit_chain
jq -e '."$schema" == "fix-impact-v1"' "$SESSION_DIR/phase7-verify/fix-impact.json" \
  || echo "FAIL T3: fix-impact.json schema mismatch"
jq -e '.audit_chain.checksum | length == 64' "$SESSION_DIR/phase7-verify/fix-impact.json" \
  || echo "FAIL T3: audit_chain.checksum invalid (not 64-char sha256)"
jq -e '.audit_chain.source_file != null' "$SESSION_DIR/phase7-verify/fix-impact.json" \
  || echo "FAIL T3: audit_chain.source_file missing"

# T4 — Pipeline Status
jq -e '.phases.phase7.status == "completed"' "$SESSION_DIR/fix-status.json" \
  || echo "FAIL T4: phase7 not completed"
jq -e '.pipeline_status == "DONE"' "$SESSION_DIR/fix-status.json" \
  || echo "FAIL T4: pipeline_status != DONE"
jq -e '.phases.phase7.completed_at != null' "$SESSION_DIR/fix-status.json" \
  || echo "FAIL T4: phase7.completed_at missing"

# T5 — Phase7-report ≤15 dòng (CORE-028)
REPORT_LINES=$(wc -l < "$SESSION_DIR/phase7-verify/Phase7-report.md")
[ "$REPORT_LINES" -le 15 ] || echo "FAIL T5: Phase7-report $REPORT_LINES > 15 dòng"
```

**Tất cả T1-T5 PASS → Pipeline END. User sẵn sàng consume fix-impact.json qua `--from-fix-bugs` flag.**

## E005 Healthy Path (N=0 issues)

```
1. Group A detect E005_HEALTHY=true → SKIP Groups B + C (không có fixes để verify)
2. Group D dashboard ghi "Hệ thống HEALTHY — không phát hiện lỗi"
3. Group E orchestrator-summary "Hệ thống healthy", fix-impact.json fixed_count=0, status="healthy"
4. Group F pipeline_status=DONE (e005_healthy=true)
5. Group G display "Hệ thống HEALTHY — không phát hiện lỗi"
6. POST-GATE T1-T5 đầy đủ (4 reports vẫn được tạo dưới dạng healthy summary)
```

## Standard TRACE FAIL Pattern (CORE-026)

> Áp dụng khi BẤT KỲ step Phase 7 fail vĩnh viễn. Reference: `_shared/06-on-failure.md`.

```bash
# _phase7_trace_fail <error_code> <error_message> [<step_id>]
# Dual-write: session-log.json + global trace + fix-status pipeline_status=failed + error-ledger
# Defined trong setup-verify.sh OR sourced từ wf-fix-common.sh
#
# Examples:
#   _phase7_trace_fail "E070" "CQG-1 numeric mismatch delta=42% > 5%" "7.2"
#   _phase7_trace_fail "E071" "CQG-2 browser smoke fail sau 2 REJECT" "7.3"
#   _phase7_trace_fail "E001" "Auto-fix budget exhausted" "7.6"
```

**v10.10.1 fix:** Function atomic `.events += [...]` (không raw `>>` — chống phá tính JSON hợp lệ).
**v10.10.0 hard exit:** Function gọi `exit 1` cuối — pipeline KHÔNG được tiếp tục sau trace_fail.

**Cross-ref:** CORE-026, CORE-034, [`_shared/06-on-failure.md`](../_shared/06-on-failure.md).

## On Failure — Quick Reference

| Code | Mô tả | Step/Group | Hành động |
|------|-------|-----------|-----------|
| E005 | Healthy Path (N=0) | A (7.1) | Không lỗi — route skip B + C |
| E001 | Pipeline state error | A (7.1) | Dừng — chạy Phase 5/6 trước |
| E060 | fix-report/issue-registry missing | A (7.1) | Dừng — Phase 6 chưa đầy đủ |
| E070 | CQG-1 numeric mismatch >5% | B (7.2) | Retry x3 → `_phase7_trace_fail "E070"` → E001 escalate |
| E071 | CQG-2 browser/integration fail | C (7.3) | CDG render. 2 REJECT → `_phase7_trace_fail "E071"` → E001 |
| E045 | Mobile evidence missing | D (7.4) | WARN — không block, ghi chú vào Phase7-report (Group E) |
| E073 | orchestrator-summary/dashboard fail | D, E (7.4, 7.5) | Retry x1 → `_phase7_trace_fail "E073"` → E001 |
| E074 | fix-impact/phase-summary/Phase7-report fail | E (7.5) | Retry x1 → `_phase7_trace_fail "E074"` → E001 |
| E075 | Atomic write / trace fail | A, F (7.1, 7.6) | Retry x1. Trace dual-write fail → WARN |
| E001 | Pipeline/session error | All | ESCALATE: AskUserQuestion "Re-run / Skip / Cancel" |

**Auto-Fix Budget:** Max 3 retries tổng cho Phase 7 (CORE-034).

## Resume Logic

```bash
PHASE7_STATUS=$(jq -r '.phases.phase7.status // "not_started"' "$SESSION_DIR/fix-status.json")
PIPELINE_STATUS=$(jq -r '.pipeline_status // "in_progress"' "$SESSION_DIR/fix-status.json")

case "$PHASE7_STATUS" in
  "completed")
    if [ "$PIPELINE_STATUS" = "DONE" ]; then echo "Phase 7 completed. Pipeline DONE.";
    else echo "WARN: phase7=completed nhưng pipeline_status != DONE — kiểm tra Group F"; fi ;;
  "in_progress")
    echo "Phase 7 đang dở — resume từ group đang dở."
    for f in orchestrator-summary.md fix-impact.json phase-summary.md Phase7-report.md; do
      [ -s "$SESSION_DIR/phase7-verify/$f" ] && echo "  ✓ $f" || echo "  ✗ $f — cần tạo"
    done
    # Re-run từ group đầu tiên chưa có output
    ;;
  *) echo "Phase 7 chưa bắt đầu. Chạy từ Group A (Step 7.1)." ;;
esac

# Stale lock check (CORE-038): >30 min → auto-release
```

## Next Step (Pipeline END)

Pipeline hoàn thành. User nên:
- `/wf-verify-sync --from-fix-bugs` để consume `fix-impact.json` (cross-skill CORE-036)
- `/status` để xem tổng quan dự án
- `git diff` để review tất cả changes

> **Contract:** Verify output files match `_contract.json §outputs.working[]` + §errors. fix-impact.json schema `fix-impact-v1` với `$schema` + `audit_chain.checksum_sha256` 64-char — chuẩn cross-skill artifact.
