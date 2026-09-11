# Phase 5 POST-GATE + Error Reference

> **Entry condition:** Group G PASS (fix-status.phase5 = completed + TRACE COMPLETE).
> **Exit condition:** All T1-T4 checks PASS → advance Phase 6.
> **Next:** Phase 6 — `procedures/phase6-execute.md` (hoặc Phase 7 nếu E005 jump xảy ra ở Group A).

## POST-GATE T1-T4 Validation

```bash
# T1 — File Existence (4 critical outputs từ triage agent + script)
test -s "$SESSION_DIR/phase5-triage/issue-registry.json"   || echo "FAIL T1: issue-registry"
test -s "$SESSION_DIR/phase5-triage/bug-triage.md"         || echo "FAIL T1: bug-triage"
test -s "$SESSION_DIR/phase5-triage/fix-plan.md"           || echo "FAIL T1: fix-plan"
test -s "$SESSION_DIR/phase5-triage/fix-log.json"          || echo "FAIL T1: fix-log"

# T2 — Structure (markdown headers + JSON shape)
grep -qE "^## " "$SESSION_DIR/phase5-triage/bug-triage.md" || echo "FAIL T2: bug-triage missing headers"
grep -qE "^## " "$SESSION_DIR/phase5-triage/fix-plan.md"   || echo "FAIL T2: fix-plan missing headers"
jq -e '.entries' "$SESSION_DIR/phase5-triage/fix-log.json" >/dev/null \
  || echo "FAIL T2: fix-log invalid JSON"

# T3 — Content Depth (CORE-012 tier 3)
TRIAGE_LINES=$(wc -l < "$SESSION_DIR/phase5-triage/bug-triage.md")
PLAN_LINES=$(wc -l < "$SESSION_DIR/phase5-triage/fix-plan.md")
[ "$TRIAGE_LINES" -ge 10 ] || echo "FAIL T3: bug-triage shallow ($TRIAGE_LINES lines)"
[ "$PLAN_LINES" -ge 15 ]   || echo "FAIL T3: fix-plan shallow ($PLAN_LINES lines)"

# T4 — Cross-Reference (counts + CDG token + safety check + finalize)
jq -e '.tokens[-1].gate == "CDG-PRE-EXECUTE" and .tokens[-1].status == "accepted"' \
  "$SESSION_DIR/phase5-triage/cdg-tokens.json" >/dev/null \
  || echo "FAIL T4: CDG-PRE-EXECUTE token missing/rejected"
test -s "$SESSION_DIR/phase5-triage/safety-check.json"     || echo "FAIL T4: safety-check missing"
jq -e '.phases.phase5.status == "completed"' "$SESSION_DIR/fix-status.json" \
  || echo "FAIL T4: phase5 not completed"
```

**Tất cả T1-T4 PASS → Phase 5 hoàn tất, advance sang Phase 6.**

## Phase 5 Report Summary

Sau POST-GATE pass, `phase5-triage/Phase5-report.md` đã được tạo (qua Group G) với:

- Status (PASS/FAIL), Started/Completed timestamps
- Total signals → Total issues (sau dedup)
- Severity distribution (Critical/High/Medium/Low)
- Triage method + Process Integrity result
- CDG decisions count (CDG-PRE-EXECUTE)
- Safety blockers count
- E005 healthy flag (nếu N=0)

## On Failure — Quick Reference

| Code | Xử lý |
|------|-------|
| E005 | N=0 issues → Jump Phase 7 (healthy). Update fix-status: phase5=completed (E005), phase6=skipped. |
| E035 | Atomic write fail → Retry x1, kiểm tra lock + quyền ghi |
| E040 | Phase 4 chưa completed → Dừng, chạy Phase 4 trước |
| E050 | Aggregator fail → Retry x1 (Python → jq fallback) → ESCALATE |
| E051 | Step verification / template / report fail → WARN, ghi error-ledger, continue |
| E052 | Process violation: critical → CDG hard-stop; high → warning + continue; low → continue |
| E053 | Triage spawn / POST-GATE fail → Re-spawn x1 → ESCALATE (E054) |
| E054 | CDG REJECT lần 3 hoặc budget hết → ESCALATE: re-run / skip / cancel |
| E055 | Safety Check blockers → CDG render. REJECT 2 lần → ESCALATE. |

**Auto-Fix Budget:** Max 3 retries tổng cho Phase 5 (CORE-034). Sau 3 lần → STOP, AskUserQuestion: "Re-run / Skip (risky) / Cancel".

## Resume Logic

| Trạng thái | Hành động |
|------------|-----------|
| `fix-status.phase5` không có | Bắt đầu từ Group A (Step 5.1) |
| `phase5.status = "completed"` | Skip → advance Phase 6 |
| `phase5.status = "completed", e005_healthy = true` | Skip Phase 6 → advance Phase 7 |
| `phase5.status = "in_progress"` | Check outputs hiện có → resume từ group tiếp theo |
| `phase5.status = "failed"` | Đọc error-ledger → quyết định re-run hoặc skip |
| `issue-registry.json` tồn tại nhưng phase5 chưa complete | Resume từ Group C/D (Step 5.4-5.5) |
| Stale lock (>30 min) | Auto-release → re-validate PRE-GATE → resume |

```bash
PHASE5_STATUS=$(jq -r '.phases.phase5.status // "not_started"' "$SESSION_DIR/fix-status.json")
E005=$(jq -r '.phases.phase5.e005_healthy // false' "$SESSION_DIR/fix-status.json")
case "$PHASE5_STATUS" in
  "completed")
    if [ "$E005" = "true" ]; then echo "Phase 5 completed (E005) → advance Phase 7";
    else echo "Phase 5 completed → advance Phase 6"; fi ;;
  "in_progress")
    [ -s "$SESSION_DIR/phase5-triage/bug-triage.md" ] && echo "Resume from Group E" \
      || echo "Resume from Group B" ;;
  "failed") echo "Check error-ledger.json" ;;
  *) echo "Start Phase 5 from Group A (Step 5.1)" ;;
esac
```

## Next Phase

Phase 6 — `procedures/phase6-execute.md` (Execute fixes + docs sync, CORE-036 cross-skill artifact ci-impact-report.json).
HOẶC Phase 7 — `procedures/phase7-verify.md` (nếu E005 healthy = N=0 issues từ Group A).
